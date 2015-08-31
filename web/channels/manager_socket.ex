require Logger

defmodule OpenAperture.Manager.Channels.ManagerSocket do
  use Phoenix.Socket

  import OpenAperture.Auth.Server

  ## Channels
  channel "build_log:*", OpenAperture.Manager.Channels.BuildLogChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  #  To deny connection, return `:error`.
  def connect(params, socket) do
    IO.puts("WebSocket params:  #{inspect params}")
    case authenticate_user(fetch_access_token(params["auth_header"])) do
      true -> {:ok, socket}
      false -> :error
    end    
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     MyApp.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil

  @doc """
  Retrieves the access token part of an authorization header, if available,
  and adds it to the conns private data with the :auth_access_token key.
  Returns the conn unchanged if the auth header is not present.
  """
  @spec fetch_access_token(String.t) :: String.t
  def fetch_access_token(auth_header) when auth_header == nil, do: nil
  def fetch_access_token(auth_header) when auth_header == "", do: nil
  def fetch_access_token(auth_header) when is_binary(auth_header), do: auth_header |> String.split(~r/bearer\s?(access_token=)?/i) |> List.last |> String.strip

  @spec build_token_string(String.t) :: String.t
  defp build_token_string(token), do: "access_token=" <> token

  def authenticate_user(access_token) do
    case access_token do
      nil -> false
      access_token ->
        token_info_url = System.get_env("MANAGER_OAUTH_VALIDATE_URL") || Application.get_env(OpenAperture.Manager, :oauth_validate_url)
        token_string = build_token_string(access_token)
        validate_token?(token_info_url, token_string)
    end    
  end
end