defmodule OpenAperture.Manager.Controllers.EtcdClusters do
  require Logger
  use OpenAperture.Manager.Web, :controller

  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Queries.EtcdCluster, as: EtcdClusterQuery
  alias OpenAperture.Manager.DB.Queries.ProductCluster, as: ProductClusterQuery

  alias FleetApi.Etcd, as: FleetApi
  alias OpenAperture.Fleet.SystemdUnit

  import OpenAperture.Manager.Router.Helpers

  # TODO: Add authentication

  plug :action

  @doc """
  List all Etcd Clusters the system knows about.
  """
  def index(conn, params) do
    # TODO: Pagination?
    clusters = case params["allow_docker_builds"] do
      true ->
        EtcdClusterQuery.get_docker_build_clusters
        |> Repo.all
        |> Enum.map &Map.from_struct/1      
      "true" ->
        EtcdClusterQuery.get_docker_build_clusters
        |> Repo.all
        |> Enum.map &Map.from_struct/1
      _ ->
        EtcdCluster
        |> Repo.all
        |> Enum.map &Map.from_struct/1
    end

    #IO.puts("clusters:  #{inspect clusters}")
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
    cluster = EtcdCluster.new(params)
    if cluster.valid? do
      try do
        cluster = Repo.insert(cluster)
        path = etcd_clusters_path(Endpoint, :show, cluster.etcd_token)

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
        {:ok, api_pid} = FleetApi.start_link(token)
        {:ok, hosts} = FleetApi.list_machines(api_pid)

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
        {:ok, api_pid} = FleetApi.start_link(token)
        {:ok, units} = FleetApi.list_units(api_pid)

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
        {:ok, api_pid} = FleetApi.start_link(token)
        {:ok, states} = FleetApi.list_unit_states(api_pid)

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
        {:ok, api_pid} = FleetApi.start_link(token)
        {:ok, hosts} = FleetApi.list_machines(api_pid)
        {:ok, units} = FleetApi.list_units(api_pid)

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
            host = Enum.find(hosts, fn h -> String.contains?(h.id, machine_id) end)
            unit = Enum.find(units, fn u -> String.contains?(u.name, unit_name) end)

            case {host, unit} do
              {nil, _} ->
                conn
                |> resp :not_found, "Unit #{unit_name} does not exist."
              {_, nil} ->
                conn
                |> resp :not_found, "Host #{machine_id} does not exist." 
              {host, unit} ->
                case SystemdUnit.execute_journal_request([host], unit, false) do
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