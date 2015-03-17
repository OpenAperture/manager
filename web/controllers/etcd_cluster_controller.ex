defmodule ProjectOmeletteManager.EtcdClusterController do
  require Logger
  use ProjectOmeletteManager.Web, :controller

  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Queries.EtcdCluster, as: EtcdClusterQuery
  alias ProjectOmeletteManager.DB.Queries.ProductCluster, as: ProductClusterQuery

  import ProjectOmeletteManager.Router.Helpers

  # TODO: Add authentication

  plug :action

  @doc """
  List all Etcd Clusters the system knows about.
  """
  def index(conn, _params) do
    # TODO: Pagination?
    clusters = EtcdCluster
               |> Repo.all
               |> Enum.map &Map.from_struct/1

    conn
    |> json clusters
  end

  @doc """
  Retrieve a specific Etcd Cluster instance, specified by its etcd token.
  """
  def show(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil -> 
        conn
        |> resp :not_found, ""
      cluster ->
        cluster = Map.from_struct(cluster)
        conn
        |> json cluster
    end
  end

  @doc """
  Create a new Etcd Cluster instance.
  """
  def register(conn, params) do
    cluster = %EtcdCluster{}
              |> Ecto.Changeset.cast(params, ~w(etcd_token))

    if cluster.valid? do
      try do
        cluster = Repo.insert(cluster)
        path = etcd_cluster_path(Endpoint, :show, cluster.etcd_token)

        conn
        |> put_resp_header("location", path)
        |> put_status(:created)
        |> json "Registered id #{cluster.id}"
      rescue
        _ ->
          conn
          |> put_status(:internal_server_error)
          |> json "An error occurred registering a cluster with the token #{params["etcd_token"]}"
      end
    else
      errors = cluster.errors
               |> Enum.into(%{})

      conn
      |> put_status(:bad_request)
      |> json errors
    end
  end

  @doc """
  Remove an Etcd Cluster instance from the database.
  """
  def destroy(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> resp :not_found, ""
      cluster ->
        try do
          Repo.delete(cluster)
          conn
          |> resp :no_content, ""
        rescue
          _ ->
            conn
            |> put_status(:internal_server_error)
            |> "An error occurred deleting the cluster with the token #{token}"
        end
    end
  end

  @doc """
  GET /clusters/:etcd_token/machines - Retrieve associated machines

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Plug.Conn
  """
  def machines(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> resp :not_found, ""
      _cluster ->
        hosts = FleetApi.Machine.list!(token)

        if hosts == nil do
          conn
          |> put_status(:internal_server_error)
          |> json %{error: "Unable to determine if machines are available"}
        else
          conn
          |> json hosts
        end
    end
  end

  @doc """
  GET /clusters/:etcd_token/units - Retrieve associated units

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Plug.Conn
  """
  def units(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> resp :not_found, ""
      _cluster ->
        units = FleetApi.Unit.list!(token)

        if units == nil do
          conn
          |> put_status(:internal_server_error)
          |> json %{error: "Unable to determine if units are available"}
        else
          conn
          |> json units
        end
    end
  end

  @doc """
  GET /clusters/:etcd_token/state - Retrieve associated units' state

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Plug.Conn
  """
  def units_state(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> resp :not_found, ""
      _cluster ->
        states = FleetApi.UnitState.list!(token)

        if states == nil do
          conn
          |> put_status(:internal_server_error)
          |> json %{error: "Unable to determine if unit states are available."}
        else
          conn
          |> json states
        end
    end
  end
  
  @doc """
  GET /clusters/:etcd_token/machines/:machine_id/units/:unit_name/logs - Retrieve associated units' state

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Plug.Conn
  """
  def unit_logs(conn, %{"etcd_token" => token, "machine_id" => machine_id, "unit_name" => unit_name}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> resp :not_found, ""
      _cluster ->
        hosts = FleetApi.Machine.list!(token)

        units = FleetApi.Unit.list!(token)

        case {hosts, units} do
          {nil, _} ->
            conn
            |> put_status(:internal_server_error)
            |> json %{error: "Unable to determine if machines are available."}
          {_, nil} ->
            conn
            |> put_status(:internal_server_error)
            |> json %{error: "Unable to determine if units are available."}
          {hosts, units} ->
            host = Enum.find(hosts, fn h -> String.contains?(h["id"], machine_id) end)
            unit = Enum.find(units, fn u -> String.contains?(u["name"], unit_name) end)

            case {host, unit} do
              {nil, _} ->
                conn
                |> resp :not_found, "Unit #{unit_name} does not exist."
              {_, nil} ->
                conn
                |> resp :not_found, "Host #{machine_id} does not exist." 
              {host, unit} ->
                case ProjectOmeletteManager.Systemd.Unit.execute_journal_request([host], unit, false) do
                  {:ok, output, error} ->
                    Logger.info "Output: #{output}"
                    Logger.info "Error: #{error}"
                    conn
                    |> json output
                  {:error, reason, _} ->
                    conn
                    |> resp :internal_server_error, "Unable to retreive logs: #{reason}"
                end
            end
        end
    end
  end

  def products(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> resp :not_found, ""
      etcd_cluster ->
        products = etcd_cluster.id
                   |> ProductClusterQuery.get_products_for_cluster
                   |> Repo.all
                   |> Enum.reduce([], fn(prod, products) ->
                        [Map.from_struct(prod) | products]
                      end)
                   |> Enum.reverse
        conn
        |> json products
    end
  end
end