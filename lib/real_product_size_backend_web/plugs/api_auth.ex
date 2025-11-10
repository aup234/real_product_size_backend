defmodule RealProductSizeBackendWeb.Plugs.ApiAuth do
  @moduledoc """
  Simplified API authentication plug for JWT tokens.
  """

  import Plug.Conn
  import Phoenix.Controller
  require Logger

  alias RealProductSizeBackend.JWTService

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info("ApiAuth: Plug called for #{conn.request_path}")

    case get_auth_token(conn) do
      {:ok, token} ->
        Logger.info("ApiAuth: Token found, verifying...")
        case JWTService.verify_access_token(token) do
          {:ok, claims} ->
            Logger.info("ApiAuth: Token verified, getting user from claims")
            user = get_user_from_claims(claims)
            Logger.info("ApiAuth: Assigning current_user: #{inspect(user.email)}")
            assign(conn, :current_user, user)

          {:error, reason} ->
            Logger.info("ApiAuth: Token verification failed: #{inspect(reason)}")
            conn
            |> put_status(401)
            |> json(%{error: "Invalid authentication token"})
            |> halt()
        end

      {:error, reason} ->
        Logger.info("ApiAuth: No token found: #{inspect(reason)}")
        conn
        |> put_status(401)
        |> json(%{error: "Authentication token required"})
        |> halt()
    end
  end

  defp get_auth_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :no_token}
    end
  end

  defp get_user_from_claims(claims) do
    require Logger
    Logger.info("Getting user from claims")

    # Get user from database using the user_id from claims
    case RealProductSizeBackend.Accounts.get_user!(claims["sub"]) do
      %RealProductSizeBackend.Accounts.User{} = user ->
        Logger.info("Found user: #{inspect(user.email)}")
        user
    end
  rescue
    # If user ID is invalid format, return error
    e ->
      Logger.error("Error getting user from claims: #{inspect(e)}")
      raise "Invalid user ID in token"
  end

  @doc """
  Helper function to get user from token without going through plug pipeline
  """
  def get_user_from_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case JWTService.verify_access_token(token) do
          {:ok, claims} ->
            user = get_user_from_claims(claims)
            {:ok, user}
          {:error, reason} ->
            {:error, reason}
        end
      _ ->
        {:error, "Missing or invalid authorization header"}
    end
  end
end
