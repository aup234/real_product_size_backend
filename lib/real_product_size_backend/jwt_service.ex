defmodule RealProductSizeBackend.JWTService do
  @moduledoc """
  Simplified JWT Service using Joken for secure token generation and verification.

  This module handles:
  - Access token generation and verification
  - Simple token management (no refresh tokens)
  """

  use Joken.Config
  require Logger

  # JWT Configuration
  @access_token_lifetime Application.compile_env(:real_product_size_backend, :jwt)[:access_token_lifetime] || 1800
  @refresh_token_lifetime Application.compile_env(:real_product_size_backend, :jwt)[:refresh_token_lifetime] || 7200
  @signing_key Application.compile_env(:real_product_size_backend, :jwt)[:signing_key] || "dev_secret_key_change_in_production"

  # Token types
  @type token_claims :: map()
  @type token_error :: {:error, String.t()}

  @doc """
  Generate an access token for a user.
  """
  @spec generate_access_token(RealProductSizeBackend.Accounts.User.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_access_token(user) do
    claims = %{
      "sub" => user.id,
      "email" => user.email,
      "type" => "access",
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(@access_token_lifetime, :second) |> DateTime.to_unix()
    }

    Logger.info("Generating access token for user: #{inspect(user.email)}")

    case Joken.encode_and_sign(claims, Joken.Signer.create("HS256", @signing_key)) do
      {:ok, token, _claims} ->
        Logger.info("Generated access token successfully")
        {:ok, token}
      {:error, reason} ->
        Logger.error("Failed to generate access token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate a refresh token for a user.
  """
  @spec generate_refresh_token(RealProductSizeBackend.Accounts.User.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_refresh_token(user) do
    claims = %{
      "sub" => user.id,
      "email" => user.email,
      "type" => "refresh",
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(@refresh_token_lifetime, :second) |> DateTime.to_unix()
    }

    Logger.info("Generating refresh token for user: #{inspect(user.email)}")

    case Joken.encode_and_sign(claims, Joken.Signer.create("HS256", @signing_key)) do
      {:ok, token, _claims} ->
        Logger.info("Generated refresh token successfully")
        {:ok, token}
      {:error, reason} ->
        Logger.error("Failed to generate refresh token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Verify an access token and return the claims.
  """
  @spec verify_access_token(String.t()) :: {:ok, token_claims()} | token_error()
  def verify_access_token(token) do
    Logger.info("Verifying access token")

    signer = Joken.Signer.create("HS256", @signing_key)

    case Joken.verify_and_validate(token_config(), token, signer) do
      {:ok, claims} ->
        # Verify this is an access token
        if claims["type"] == "access" do
          Logger.info("Access token verified successfully")
          {:ok, claims}
        else
          Logger.info("Token verification failed: Invalid token type")
          {:error, "Invalid token type"}
        end
      {:error, reason} ->
        Logger.info("Token verification failed: #{inspect(reason)}")
        error_message = case reason do
          {:message, msg} when is_binary(msg) -> msg
          msg when is_binary(msg) -> msg
          _other -> "Token verification failed"
        end
        {:error, error_message}
    end
  end

  @doc """
  Verify a refresh token and return the claims.
  """
  @spec verify_refresh_token(String.t()) :: {:ok, token_claims()} | token_error()
  def verify_refresh_token(token) do
    Logger.info("Verifying refresh token")

    signer = Joken.Signer.create("HS256", @signing_key)

    case Joken.verify_and_validate(token_config(), token, signer) do
      {:ok, claims} ->
        # Verify this is a refresh token
        if claims["type"] == "refresh" do
          Logger.info("Refresh token verified successfully")
          {:ok, claims}
        else
          Logger.info("Token verification failed: Invalid token type")
          {:error, "Invalid token type"}
        end
      {:error, reason} ->
        Logger.info("Token verification failed: #{inspect(reason)}")
        error_message = case reason do
          {:message, msg} when is_binary(msg) -> msg
          msg when is_binary(msg) -> msg
          _other -> "Token verification failed"
        end
        {:error, error_message}
    end
  end

  @doc """
  Extract user ID from token claims.
  """
  @spec get_user_id_from_token(String.t()) :: {:ok, String.t()} | token_error()
  def get_user_id_from_token(token) do
    case verify_access_token(token) do
      {:ok, claims} -> {:ok, claims["sub"]}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extract user email from token claims.
  """
  @spec get_user_email_from_token(String.t()) :: {:ok, String.t()} | token_error()
  def get_user_email_from_token(token) do
    case verify_access_token(token) do
      {:ok, claims} -> {:ok, claims["email"]}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private functions


  # Joken configuration
  @impl true
  def token_config do
    default_claims()
    |> add_claim("sub", nil, fn sub, _claims, _context -> is_binary(sub) and byte_size(sub) > 0 end)
    |> add_claim("email", nil, fn email, _claims, _context -> is_binary(email) and String.contains?(email, "@") end)
    |> add_claim("type", nil, fn type, _claims, _context -> is_binary(type) and type in ["access", "refresh"] end)
  end
end
