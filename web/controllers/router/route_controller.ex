defmodule OpenAperture.Manager.Controllers.Router.RouteController do
  use OpenAperture.Manager.Web, :controller

  require Logger

  import Ecto.Query
  import OpenAperture.Manager.Controllers.FormatHelper
  import OpenAperture.Manager.Controllers.Router.Util
  import OpenAperture.Manager.Plugs.Params
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.DB.Models.Router.Authority
  alias OpenAperture.Manager.DB.Models.Router.Route
  alias OpenAperture.Manager.Endpoint

  plug :parse_as_integer, "parent_id"
  plug :parse_as_integer, "id"
  plug :parse_as_integer, {"authority_id", 400}
  plug :parse_as_integer, {"port", 400}
  plug :validate_param, {"hostname", &Kernel.is_binary/1}

  plug :action

  @sendable_fields [:id, :authority_id, :hostname, :port, :secure_connection, :inserted_at, :updated_at]

  # GET "/router/authorities/:parent_id/routes?hostspec=[:hostname]:[:port]"
  def index(conn, %{"parent_id" => authority_id, "hostspec" => hostspec}) do
    case parse_hostspec(hostspec) do
      {:ok, hostname, port} ->
        query = Route
                |> where([r], r.authority_id == ^authority_id)
                |> where([r], fragment("lower(?) = lower(?)", r.hostname, ^hostname))
                |> where([r], r.port == ^port)

        case Repo.one(query) do
          nil ->
            resp(conn, :not_found, "")
          route ->
            json conn, to_sendable(route, @sendable_fields)
        end
      :error ->
        resp(conn, :bad_request, "")
    end
  end

  # GET "/router/authorities/:parent_id/routes"
  def index(conn, %{"parent_id" => authority_id}) do
    query = Authority
            |> where([a], a.id == ^authority_id)
            |> preload(:routes)

    case Repo.one(query) do
      nil ->
        resp(conn, :not_found, "")
      authority ->
        routes = Enum.map(authority.routes, &(to_sendable(&1, @sendable_fields)))
        json conn, routes
    end
  end

  # DELETE "/router/authorities/:parent_id/routes/clear"
  def clear(conn, %{"parent_id" => authority_id}) do
    case Repo.get(Authority, authority_id) do
      nil ->
        resp(conn, :not_found, "")
      authority ->
        result = Repo.transaction(fn ->
          Route
          |> where([r], r.authority_id == ^authority.id)
          |> Repo.delete_all

          authority
          |> Authority.validate_changes(%{updated_at: Ecto.DateTime.utc})
          |> Repo.update!
        end)

        case result do
          {:ok, _} ->
            resp(conn, :no_content, "")
          {:error, error} ->
            Logger.error "An error occurred clearing the routes for authority: #{authority.id}: #{inspect error}"
            resp(conn, :internal_server_error, "")
        end
    end
  end

  # DELETE "/router/authorities/:parent_id/routes/:id"
  def delete(conn, %{"parent_id" => authority_id, "id" => id}) do
    case get_authority_and_route(authority_id, id) do
      {authority, route} when authority != nil and route != nil ->
        result = Repo.transaction(fn ->
          Repo.delete!(route)

          authority
          |> Authority.validate_changes(%{updated_at: Ecto.DateTime.utc})
          |> Repo.update!
        end)

        case result do
          {:ok, _} ->
            resp(conn, :no_content, "")
          {:error, error} ->
            Logger.error "An error occurred deleting route #{id}: #{inspect error}"
            resp(conn, :internal_server_error, "")
        end
      _ ->
        resp(conn, :not_found, "")
    end
  end

  # POST "/router/authorities/:parent_id/routes"
  def create(conn, %{"parent_id" => authority_id, "hostname" => hostname, "port" => port} = params) do
    query = Authority
            |> join(:left, [a], r in Route, r.authority_id == a.id and fragment("lower(?) = lower(?)", r.hostname, ^hostname) and r.port == ^port)
            |> where([a, r], a.id == ^authority_id)
            |> select([a, r], {a, r})

    case Repo.one(query) do
      nil -> resp(conn, :not_found, "")
      {_host, existing_route} when existing_route != nil ->
        resp(conn, :conflict, "")
      {authority, nil} ->
        changeset = Route.validate_changes(%Route{authority_id: authority_id}, params)
        if changeset.valid? do
          result = Repo.transaction(fn ->
            route = Repo.insert!(changeset)

            authority
            |> Authority.validate_changes(%{updated_at: Ecto.DateTime.utc})
            |> Repo.update!

            route
          end)

          case result do
            {:ok, route} ->
              path = route_path(Endpoint, :show, authority.id, route.id)
              conn
              |> put_resp_header("location", path)
              |> resp(:created, "")
            {:error, error} ->
              Logger.error "Error creating new route for authority #{authority.id}: #{inspect error}"
              resp(conn, :internal_server_error, "")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json inspect(changeset.errors)
        end
    end
  end

  # This action only matches if a param is missing
  def create(conn, _params) do
    resp(conn, :bad_request, "hostname and port are required")
  end

  # PUT/PATCH "/router/authorities/:authority_id/routes/:id"
  def update(conn, %{"parent_id" => authority_id, "id" => id} = params) do
    case get_authority_and_route(authority_id, id) do
      {authority, route} when authority != nil and route != nil ->
        changeset = Route.validate_changes(route, params)
        if changeset.valid? do
          # Double-check the update won't clash with an existing route
          {_source, hostname} = Ecto.Changeset.fetch_field(changeset, :hostname)
          {_source, port} = Ecto.Changeset.fetch_field(changeset, :port)
          query = Route
                  |> where([r], r.authority_id == ^authority.id)
                  |> where([r], r.id != ^route.id)
                  |> where([r], fragment("lower(?) = lower(?)", r.hostname, ^hostname))
                  |> where([r], r.port == ^port)

          case Repo.one(query) do
            nil ->
              result = Repo.transaction(fn ->
                Repo.update!(changeset)
                authority
                |> Authority.validate_changes(%{updated_at: Ecto.DateTime.utc})
                |> Repo.update!
              end)

              case result do
                {:ok, _} ->
                  path = route_path(Endpoint, :show, authority.id, route.id)
                  conn
                  |> put_resp_header("location", path)
                  |> resp(:no_content, "")
                {:error, error} ->
                  Logger.error "An error occurred updating route #{route.id}: #{inspect error}"
                  resp(conn, :internal_server_error, "")
              end
            _route ->
              resp(conn, :conflict, "")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json inspect(changeset.errors)
        end
      _ ->
        resp(conn, :not_found, "")
    end
  end

  @spec get_authority_and_route(integer, integer) :: {Authority.t, Route.t} | {Authority.t, nil} | nil
  defp get_authority_and_route(authority_id, route_id) do
    Authority
    |> join(:left, [a], r in Route, r.authority_id == a.id and r.id == ^route_id)
    |> where([a, r], a.id == ^authority_id)
    |> select([a, r], {a, r})
    |> Repo.one
  end
end