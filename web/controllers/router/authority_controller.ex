defmodule OpenAperture.Manager.Controllers.Router.AuthorityController do
  use OpenAperture.Manager.Web, :controller

  require Logger

  import Ecto.Query
  import OpenAperture.Manager.Controllers.FormatHelper
  import OpenAperture.Manager.Controllers.Router.Util
  import OpenAperture.Manager.Plugs.Params
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.DB.Models.Router.Authority
  alias OpenAperture.Manager.DB.Models.Router.DeletedAuthority
  alias OpenAperture.Manager.DB.Models.Router.Route
  alias OpenAperture.Manager.Endpoint

  plug :parse_as_integer, "id"
  plug :parse_as_integer, {"port", 400}
  plug :validate_param, {"hostname", &Kernel.is_binary/1}

  @sendable_fields [:id, :hostname, :port, :inserted_at, :updated_at]

  # GET /router/authorities?hostspec=somehost%4Asomeport
  def swaggerdoc_index, do: %{
    description: "Retrieve all Authorities",
    response_schema: %{"title" => "Authorities", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Router.Authority"}},
    parameters: []
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def index(conn, %{"hostspec" => hostspec}) do
    case parse_hostspec(hostspec) do
      {:ok, hostname, port} ->
        case get_authority_by_hostname_and_port(hostname, port) do
          nil ->
            resp conn, :not_found, ""
          authority ->
            json conn, to_sendable(authority, @sendable_fields)
        end
      :error ->
        resp conn, :bad_request, ""
    end
  end

  # GET /router/authorities
  def index(conn, _params) do
    authorities = Authority
                  |> Repo.all
                  |> Enum.map(&to_sendable(&1, @sendable_fields))

    json conn, authorities
  end

  # This endpoint is used by the UI to retrieve all the authorities & route
  # info at once, so we don't have to make multiple calls.
  # GET /router/authorities/full
  def swaggerdoc_index_detailed, do: %{
    description: "Retrieve all Authorities and route info",
    response_schema: %{"title" => "Authorities", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Router.Authority"}},
    parameters: []
  }    
  @spec index_detailed(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def index_detailed(conn, _params) do
    authorities = Authority
                  |> preload(:routes)
                  |> Repo.all
                  |> Enum.map(fn authority ->
                    routes = Enum.map(authority.routes, &format_route/1)
                    authority = to_sendable(authority, @sendable_fields)
                    Map.put(authority, :routes, routes)
                  end)

    json conn, authorities
  end

  defp format_route(route) do
    to_sendable(route, [:id, :hostname, :port, :secure_connection])
  end

  # GET /router/authorities/:id
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific Authority",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Router.Authority"},
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "Authority identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def show(conn, %{"id" => id}) do
    case Repo.get(Authority, id) do
      nil -> resp conn, :not_found, ""
      authority -> json conn, to_sendable(authority, @sendable_fields)
    end
  end

  # GET /router/authorities/:id/detailed
  def swaggerdoc_show_detailed, do: %{
    description: "Retrieve a specific Authority with details",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Router.Authority"},
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "Authority identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec show_detailed(Plug.Conn.t, [any]) :: Plug.Conn.t   
  def show_detailed(conn, %{"id" => id}) do
    Authority
    |> preload(:routes)
    |> Repo.get(id)
    |> case do
      nil -> resp conn, :not_found, ""
      authority ->
        routes = Enum.map(authority.routes, &format_route/1)
        authority = authority
                    |> to_sendable(@sendable_fields)
                    |> Map.put(:routes, routes)

        json conn, authority
    end
  end

  # DELETE /router/authorities/:id
  def swaggerdoc_delete, do: %{
    description: "Delete an Authority" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "Authority identifier",
      "required" => true,
      "type" => "integer"
    }]
  }  
  @spec delete(Plug.Conn.t, [any]) :: Plug.Conn.t
  def delete(conn, %{"id" => id}) do
    case Repo.get(Authority, id) do
      nil -> resp conn, :not_found, ""
      authority ->
        result = Repo.transaction(fn ->
          Route
          |> where([r], r.authority_id == ^id)
          |> Repo.delete_all

          # Create a deleted_authority record
          %DeletedAuthority{}
          |> DeletedAuthority.validate_changes(%{hostname: authority.hostname, port: authority.port})
          |> Repo.insert!

          Repo.delete!(authority)
        end)

        case result do
          {:ok, _} -> resp conn, :no_content, ""
          error ->
            Logger.error "Error deleting authority: #{inspect error}"
            resp conn, :internal_server_error, ""
        end
    end
  end

  # POST /router/authorities
  def swaggerdoc_create, do: %{
    description: "Create an Authority" ,
    parameters: [%{
      "name" => "type",
      "in" => "body",
      "description" => "The new Authority",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Router.Authority"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def create(conn, %{"hostname" => hostname, "port" => port} = _params) when hostname != nil and port != nil do
    case get_authority_by_hostname_and_port(hostname, port) do
      nil ->
        changeset = Authority.validate_changes(%Authority{}, %{hostname: hostname, port: port})
        if changeset.valid? do
          authority = Repo.insert!(changeset)
          path = authority_path(Endpoint, :show, authority)

          conn
          |> put_resp_header("location", path)
          |> resp(:created, "")
        else
          conn
          |> put_status(:bad_request)
          |> json inspect(changeset.errors)
        end
      _authority ->
        resp(conn, :conflict, "")
    end
  end

  # This action only matches if a param is missing
  def create(conn, _params) do
    Plug.Conn.resp(conn, :bad_request, "hostname and port are required")
  end

  # PUT/PATCH /router/authorities/:id
  def swaggerdoc_update, do: %{
    description: "Update an Authority" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "Authority identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated Authority",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Router.Authority"}
    }]
  }  
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def update(conn, %{"id" => id} = params) do
    case Repo.get(Authority, id) do
      nil -> resp conn, :not_found, ""
      authority ->
        changeset = Authority.validate_changes(authority, params)
        if changeset.valid? do
          {_source, hostname} = Ecto.Changeset.fetch_field(changeset, :hostname)
          {_source, port} = Ecto.Changeset.fetch_field(changeset, :port)

          existing = get_authority_by_hostname_and_port(hostname, port)

          if existing == nil || existing.id == authority.id do
            result = Repo.transaction(fn ->
              # Create a deleted_authority record, since we want the router
              # instances to purge any record of the old host:port combo from
              # their caches.
              %DeletedAuthority{}
              |> DeletedAuthority.validate_changes(%{hostname: authority.hostname, port: authority.port})
              |> Repo.insert!

              Repo.update!(changeset, [force: true])
            end)

            case result do
              {:ok, authority} ->
                path = authority_path(Endpoint, :show, authority)

                conn
                |> put_resp_header("location", path)
                |> resp(:no_content, "")
              {:error, error} ->
                Logger.error "Error updating authority #{authority.id}: #{inspect error}"
                resp conn, :internal_server_error, ""
            end
          else
            resp(conn, :conflict, "")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json inspect(changeset.errors)
        end
    end
  end

  @spec get_authority_by_hostname_and_port(String.t, integer) :: Authority.t | nil
  defp get_authority_by_hostname_and_port(hostname, port) do
    Authority
    |> where([a], fragment("lower(?) = lower(?)", a.hostname, ^hostname))
    |> where([a], a.port == ^port)
    |> Repo.one
  end


end