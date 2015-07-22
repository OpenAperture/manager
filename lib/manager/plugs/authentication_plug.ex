defmodule OpenAperture.Manager.Plugs.Authentication do
  @moduledoc """
  This module contains an authentication filter for incoming requests.
  """
  require Logger
  import Plug.Conn
  import OpenAperture.Auth.Server
  import Ecto.Query

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.AuthSource
  alias OpenAperture.Manager.DB.Models.AuthSourceUserRelation
  alias OpenAperture.Manager.DB.Models.User

  @doc """
  Retrieves the access token part of an authorization header, if available,
  and adds it to the conns private data with the :auth_access_token key.
  Returns the conn unchanged if the auth header is not present.
  """
  @spec fetch_access_token(Plug.Conn.t, [any]) :: Plug.Conn.t
  def fetch_access_token(conn, _opts) do
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
    Logger.debug("Validating access token against url #{token_info_url}...")

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
    url = System.get_env("MANAGER_OAUTH_VALIDATE_URL") || Application.get_env(OpenAperture.Manager, :oauth_validate_url)
    authenticate_user(conn, [token_info_url: url])
  end

  @doc """
  This plug fetches the user record (or creates a new one) for the
  user associated to the current access token
  """
  @spec fetch_user(Plug.Conn.t, [any]) :: Plug.Conn.t
  def fetch_user(conn, [token_info_url: token_info_url]) do
    case conn.private[:auth_access_token] do
      nil -> conn
      access_token ->
        token_string = build_token_string(access_token)
        case token_info(token_info_url, token_string) do
          {_, info} ->
            auth_source = get_auth_source_for_token_url(token_info_url)
            user = get_user(auth_source, info)

            if user != nil do
              conn = put_private(conn, :auth_user, user)
            end

            conn
          nil -> conn
        end
    end
  end

  def fetch_user(conn, _opts) do
    url = System.get_env("MANAGER_OAUTH_VALIDATE_URL") || Application.get_env(OpenAperture.Manager, :oauth_validate_url)
    fetch_user(conn, [token_info_url: url])
  end  

  @spec build_token_string(String.t) :: String.t
  defp build_token_string(token), do: "access_token=" <> token

  # Retrieves the auth source record for the associated token info url,
  # creating a new auth source record if one doesn't exist.
  @spec get_auth_source_for_token_url(String.t) :: AuthSource.t | nil
  defp get_auth_source_for_token_url(token_info_url) do
    query = where(AuthSource, [as], as.token_info_url == ^token_info_url)

    case Repo.one(query) do
      nil ->
        # No AuthSource exists for this token info url, so we'll need to
        # create a new one.
        auth_source = %AuthSource{
          name: "auto-generated",
          token_info_url: token_info_url,
          email_field_name: "resource_owner/email",
          first_name_field_name: "resource_owner/custom_attributes/first_name",
          last_name_field_name: "resource_owner/custom_attributes/last_name"
        }
        case transactional_insert(auth_source, query) do
          {:ok, auth_source} -> auth_source
          nil -> nil
        end

      auth_source -> auth_source
    end
  end

  # Handle the case where a corresponding auth_source doesn't exist.
  defp get_user(nil, _token_info), do: nil

  # Retrieves the user with the associated email address, creating the user
  # record if one doesn't exist.
  @spec get_user(AuthSource.t, Map.t) :: User.t | nil
  defp get_user(auth_source, token_info) do
    email = get_field_from_token_info(token_info, auth_source.email_field_name, "")

    user_query = where(User, [u], u.email == ^email)

    user = case Repo.one(user_query) do
      nil ->
        # No user exists with this email, so we'll need to create a new one.
        first_name = get_field_from_token_info(token_info, auth_source.first_name_field_name, "OpenAperture")
        last_name = get_field_from_token_info(token_info, auth_source.last_name_field_name, "User")

        user = %User{first_name: first_name, last_name: last_name, email: email}

        case transactional_insert(user, user_query) do
          {:ok, user} -> user
          nil -> nil
        end

      user_record -> user_record
    end

    # Make sure user is associated to this auth source, if not, associate them.
    asur_query = AuthSourceUserRelation
                 |> where([asur], asur.auth_source_id == ^auth_source.id)
                 |> where([asur], asur.user_id == ^user.id)

    if Repo.one(asur_query) == nil do
      # No relation exists, create it
      relation = %AuthSourceUserRelation{auth_source_id: auth_source.id, user_id: user.id}

      transactional_insert(relation, asur_query)
    end

    user
  end

  # Utility function to do potentially deep-nested retrievals from the
  # token_info map based on the path specified by field_name.
  # Ex: If field name is "level1/level2/level3", will effectively perform
  # a lookup like token_info["level1"]["level2"]["level3"]
  @spec get_field_from_token_info(Map.t, String.t, any) :: any
  defp get_field_from_token_info(token_info, field_name, default) do
    parts = String.split(field_name, "/")
    case get_in(token_info, parts) do
      nil -> default
      field -> field
    end
  end

  # Because the API may get hit by multiple near-simultaneous authentication
  # requests, and we're provisionally creating new auth source, user, and
  # relation models for any new auth sources or users, we can accidentally get
  # into a db-based race condition where two different requests try to create
  # the same user. `transactional_insert/2` wraps the creation of these records
  # so that we'll only ever insert a single unique record.
  # Parameters: 
  # model - The model or changeset record you want to insert
  # unique_query - A unique query (only a single possible matching record)
  #                used to determine if a matching record already exists.
  @spec transactional_insert(Ecto.Model.t | Ecto.Changeset.t, Ecto.Query.t) :: {:ok, Ecto.Model.t} | nil
  defp transactional_insert(model, unique_query) do
    tx_result = Repo.transaction(fn ->
      try do
        Repo.insert!(model)
      rescue _ ->
        Repo.rollback(:error)
      end
    end)

    case tx_result do
      {:error, _reason} ->
        # If an error occurred on insert, it's probably because we're trying
        # to create a duplicate record. Use the unique_query to check if our
        # record now exists, and if so, return it. If not, something else has
        # gone wrong, so just return nil.
        case Repo.one(unique_query) do
          nil -> nil
          record -> {:ok, record}
        end
      success -> success
    end
  end
end
