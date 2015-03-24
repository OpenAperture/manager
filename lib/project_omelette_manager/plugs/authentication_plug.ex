#
# == uthentication_plug.ex
#
# This module contains an authentication filter for incoming requests.
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
require Logger

defmodule ProjectOmeletteManager.Plugs.Authentication do
  import Plug.Conn

  @moduledoc """
  This module contains an authentication filter for incoming requests.
  """

  @doc """
  Initialization logic for the plug
  ## Options
  The `args` option defines an array of arguments.
  ## Return Values
  Array of options
  """
  @spec init([any]) :: [any]
  def init(options) do
    # initialize options
    options
  end

  @doc """
  Method called to process the HTTP request
  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `_opts` option defines an array of arguments.
  ## Return Values
  Underlying HTTP connection.
  """
  @spec call(term, [any]) :: term
  def call(conn, _options) do
    Logger.debug("Verifying authentication...")
    case List.keyfind(conn.req_headers, "authorization", 0) do
      nil ->
        conn
        |> send_resp(401, "Unauthorized!")
        |> halt
      {"authorization", auth_header} ->
        try do
          case authenticate_request(Application.get_env(:cloudos_manager, :oauth_validate_url), auth_header) do
            true -> 
              Logger.debug("Request authentication was validated")
              conn
            false ->
              Logger.debug("Request authentication was rejected")
              conn
              |> send_resp(401, "Unauthorized!")
              |> halt            
          end
        rescue e in _ ->
          Logger.error("Unable to authentication request, an unknown error has occurred:  #{inspect e}")
          conn
          |> send_resp(500, "Unable to authentication request, an unknown error has occurred!")
          |> halt                      
        end
    end
  end

  @doc false
  # Method to validate a request header.  Will try psw, peppr, and google auth
  # 
  ## Options
  # 
  # The `auth_header` option defines the String authentication header
  # 
  ## Return values
  # 
  # boolean
  # 
  @spec authenticate_request(String.t(), String.t()) :: term
  defp authenticate_request(url, auth_header) do
    Logger.debug("Attempting to validate auth header...")
    if (!String.starts_with?(auth_header, "OAuth ")) do
      false
    else
      access_token = to_string(tl(String.split(auth_header, "OAuth ")))    
      CloudosAuth.Server.validate_header(url, access_token)
    end
  end
end