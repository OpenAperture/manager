require Logger

defmodule OpenAperture.Manager.Plugs.Authentication do
  @moduledoc """
  This module contains an authentication filter for incoming requests.
  """
  import Plug.Conn
  import OpenAperture.Auth.Server

  @token_info_url Application.get_env(OpenAperture.Manager, :oauth_validate_url)

  @doc """
  Retrieves the access token part of an authorization header, if available,
  and adds it to the conns private data with the :auth_access_token key.
  Returns the conn unchanged if the auth header is not present.
  """
  @spec fetch_access_token(Plug.Conn.t, [any]) :: Plug.Conn.t
  def fetch_access_token(conn, _opts) do
    Logger.debug("Fetching access token from auth header")
    case get_req_header(conn, "authorization") do
      [auth_header] when is_binary(auth_header) ->
        access_token = auth_header
                       |> String.split(~r/bearer\s?(access_token=)?/i)
                       |> List.last
                       |> String.strip

        if access_token != "" do
          conn = put_private(conn, :auth_access_token, access_token)
        end

        conn

      _ ->
        conn
    end
  end

  @doc """
  Retrieves the access token set in the conn's private data by
  `get_access_token/2` and checks it against the provided token info URL.
  If no access token is present, or the token validation check fails, returns
  a status of 401 to the client and halts request processing. Otherwise, just
  returns `conn`.
  """
  @spec authenticate_user(Plug.Conn.t, [any]) :: Plug.Conn.t
  def authenticate_user(conn, [token_info_url: token_info_url]) do
    Logger.debug("Validating access token...")

    case conn.private[:auth_access_token] do
      nil ->
        conn
        |> send_resp(:unauthorized, "Unauthorized")
        |> halt
      access_token ->
        token_string = build_token_string(access_token)
        case validate_token?(token_info_url, token_string) do
          true ->
            Logger.debug("Access token was validated")
            conn
          false ->
            Logger.debug("Access token is invalid")
            conn
            |> send_resp(:unauthorized, "Unauthorized")
            |> halt
        end
    end
  end

  def authenticate_user(conn, _opts) do
    url = Application.get_env(OpenAperture.Manager, :oauth_validate_url)
    authenticate_user(conn, [token_info_url: url])
  end

  # @spec fetch_user(Plug.Conn.t, [any]) :: Plug.Conn.t
  # def fetch_user(conn, [token_info_url: token_info_url]) do
  #   case conn.private[:auth_access_token] do
  #     nil -> conn
  #     access_token ->
  #       token_string = build_token_string(access_token)
  #       case token_info(token_info_url, token_string) do
  #         {_, token_info} ->

  #         nil -> conn
  #       end
  #   end
  # end

  @spec build_token_string(String.t) :: String.t
  defp build_token_string(token), do: "access_token=" <> token
end
