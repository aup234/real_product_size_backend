defmodule RealProductSizeBackendWeb.Api.AuthController do
  use RealProductSizeBackendWeb, :controller

  alias RealProductSizeBackend.{Accounts, JWTService}

  require Logger

  @doc """
  User registration endpoint.
  """
  def register(conn, %{"email" => email, "password" => password, "password_confirmation" => password_confirmation}) do
    user_params = %{
      "email" => email,
      "password" => password,
      "password_confirmation" => password_confirmation
    }

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Generate access and refresh tokens
        case {JWTService.generate_access_token(user), JWTService.generate_refresh_token(user)} do
          {{:ok, access_token}, {:ok, refresh_token}} ->
            # Track registration analytics
            track_user_registration(user)

            conn
            |> put_status(201)
            |> json(%{
              message: "User registered successfully",
              user: %{
                id: user.id,
                email: user.email,
                confirmed_at: user.confirmed_at
              },
              access_token: access_token,
              refresh_token: refresh_token,
              token_type: "Bearer",
              expires_in: Application.get_env(:real_product_size_backend, :jwt)[:access_token_lifetime] || 1800
            })

          {{:error, reason}, _} ->
            conn
            |> put_status(500)
            |> json(%{error: "Failed to generate access token", details: reason})

          {_, {:error, reason}} ->
            conn
            |> put_status(500)
            |> json(%{error: "Failed to generate refresh token", details: reason})
        end

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        error_message = get_user_friendly_error_message(errors)

        conn
        |> put_status(422)
        |> json(%{
          error: error_message,
          details: errors,
          code: get_error_code(errors)
        })
    end
  end

  @doc """
  User login endpoint.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(401)
        |> json(%{
          error: "Invalid credentials",
          message: "Email or password is incorrect"
        })

      user ->
        # Generate access and refresh tokens
        case {JWTService.generate_access_token(user), JWTService.generate_refresh_token(user)} do
          {{:ok, access_token}, {:ok, refresh_token}} ->
            # Update last authenticated time
            _update_user_authenticated_at(user)

            # Track login analytics
            track_user_login(user)

            conn
            |> put_status(200)
            |> json(%{
              message: "Login successful",
              user: %{
                id: user.id,
                email: user.email,
                confirmed_at: user.confirmed_at
              },
              access_token: access_token,
              refresh_token: refresh_token,
              token_type: "Bearer",
              expires_in: Application.get_env(:real_product_size_backend, :jwt)[:access_token_lifetime] || 1800
            })

          {{:error, reason}, _} ->
            conn
            |> put_status(500)
            |> json(%{error: "Failed to generate access token", details: reason})

          {_, {:error, reason}} ->
            conn
            |> put_status(500)
            |> json(%{error: "Failed to generate refresh token", details: reason})
        end
    end
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case JWTService.verify_refresh_token(refresh_token) do
      {:ok, claims} ->
        # Get user from refresh token claims
        try do
          user = Accounts.get_user!(claims["sub"])

          # Generate new access and refresh tokens
          case {JWTService.generate_access_token(user), JWTService.generate_refresh_token(user)} do
            {{:ok, access_token}, {:ok, new_refresh_token}} ->
              conn
              |> put_status(200)
              |> json(%{
                message: "Token refreshed successfully",
                user: %{
                  id: user.id,
                  email: user.email,
                  confirmed_at: user.confirmed_at
                },
                access_token: access_token,
                refresh_token: new_refresh_token,
                token_type: "Bearer",
                expires_in: Application.get_env(:real_product_size_backend, :jwt)[:access_token_lifetime] || 1800
              })

            {{:error, reason}, _} ->
              conn
              |> put_status(500)
              |> json(%{error: "Failed to generate access token", details: reason})

            {_, {:error, reason}} ->
              conn
              |> put_status(500)
              |> json(%{error: "Failed to generate refresh token", details: reason})
          end
        rescue
          Ecto.NoResultsError ->
            conn
            |> put_status(401)
            |> json(%{
              error: "Invalid refresh token",
              message: "User not found"
            })
        end

      {:error, reason} ->
        conn
        |> put_status(401)
        |> json(%{
          error: "Invalid refresh token",
          message: reason
        })
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{
      error: "Missing refresh token",
      message: "refresh_token parameter is required"
    })
  end

  @doc """
  Get current user profile.
  """
  def me(conn, _params) do
    user = conn.assigns.current_user

    conn
    |> put_status(200)
    |> json(%{
      user: %{
        id: user.id,
        email: user.email,
        confirmed_at: user.confirmed_at,
        created_at: user.inserted_at,
        updated_at: user.updated_at
      }
    })
  end

  # Private functions

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp get_user_friendly_error_message(errors) do
    cond do
      Map.has_key?(errors, :email) && _error_contains?(errors.email, "has already been taken") ->
        "This email is already registered. Try logging in instead."

      Map.has_key?(errors, :email) && _error_contains?(errors.email, "must have the @ sign") ->
        "Please enter a valid email address."

      Map.has_key?(errors, :password) && _error_contains?(errors.password, "should be at least") ->
        "Password must be at least 8 characters long."

      Map.has_key?(errors, :password_confirmation) && _error_contains?(errors.password_confirmation, "does not match") ->
        "Passwords do not match. Please try again."

      Map.has_key?(errors, :email) ->
        "Please check your email address."

      Map.has_key?(errors, :password) ->
        "Please check your password."

      true ->
        "Please check your information and try again."
    end
  end

  # Get error code for programmatic handling
  defp get_error_code(errors) do
    cond do
      Map.has_key?(errors, :email) && _error_contains?(errors.email, "has already been taken") ->
        "EMAIL_ALREADY_EXISTS"

      Map.has_key?(errors, :email) && _error_contains?(errors.email, "must have the @ sign") ->
        "INVALID_EMAIL_FORMAT"

      Map.has_key?(errors, :password) && _error_contains?(errors.password, "should be at least") ->
        "PASSWORD_TOO_SHORT"

      Map.has_key?(errors, :password_confirmation) && _error_contains?(errors.password_confirmation, "does not match") ->
        "PASSWORD_MISMATCH"

      Map.has_key?(errors, :email) ->
        "EMAIL_INVALID"

      Map.has_key?(errors, :password) ->
        "PASSWORD_INVALID"

      true ->
        "VALIDATION_ERROR"
    end
  end

  # Helper function to check if error message contains text (handles both strings and lists)
  defp _error_contains?(error_value, search_text) do
    case error_value do
      nil -> false
      value when is_binary(value) -> String.contains?(value, search_text)
      value when is_list(value) ->
        Enum.any?(value, fn item ->
          is_binary(item) && String.contains?(item, search_text)
        end)
      _ -> false
    end
  end

  defp track_user_registration(user) do
    # Track user registration for analytics
    Logger.info("User registered: #{user.email}")
  end

  defp track_user_login(user) do
    # Track user login for analytics
    Logger.info("User logged in: #{user.email}")
  end

  defp _update_user_authenticated_at(user) do
    # Update user's last authenticated time
    Accounts.update_user(user, %{authenticated_at: DateTime.utc_now()})
  end
end
