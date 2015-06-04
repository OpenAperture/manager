defmodule OpenAperture.Manager.Controllers.EtcdClusters do
  require Logger
  use OpenAperture.Manager.Web, :controller

  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Queries.EtcdCluster, as: EtcdClusterQuery
  alias OpenAperture.Manager.DB.Queries.ProductCluster, as: ProductClusterQuery

  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter

  alias OpenAperture.Manager.Messaging.FleetManagerPublisher
  alias OpenAperture.Messaging.AMQP.RpcHandler

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
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
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
    cluster = EtcdCluster.new(%{:etcd_token => params["etcd_token"], 
                                :hosting_provider_id => params["hosting_provider_id"],
                                :allow_docker_builds => params["allow_docker_builds"],
                                :messaging_exchange_id => params["messaging_exchange_id"]})
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
          |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
      end
    else

      conn
      |> put_status(:bad_request)
      |> json ResponseBodyFormatter.error_body(cluster.errors, "EtcdCluster")
    end
  end

  @doc """
  Remove an Etcd Cluster instance from the database.
  """
  def destroy(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        try do
          Repo.delete(cluster)
          conn
          |> resp :no_content, ""
        rescue
          _ ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
        end
    end
  end

  @doc """
  GET /clusters/:etcd_token/products - Retrieve associated products

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Plug.Conn
  """
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
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        handler = FleetManagerPublisher.list_machines!(token, cluster.messaging_exchange_id)
        case RpcHandler.get_response(handler) do
          {:ok, hosts} ->
            if hosts == nil do
              conn
              |> put_status(:internal_server_error)
              |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
            else
              Logger.debug("====>hosts:  #{inspect hosts}")
              conn
              |> json hosts
            end
          {:error, reason} -> 
            Logger.error("Received the following error retrieving hosts:  #{inspect reason}")
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
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
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        handler = FleetManagerPublisher.list_units!(token, cluster.messaging_exchange_id)
        case RpcHandler.get_response(handler) do
          {:ok, units} ->
            if units == nil do
              conn
              |> put_status(:internal_server_error)
              |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
            else
              conn
              |> json units
            end
          {:error, reason} -> 
            Logger.error("Received the following error retrieving units:  #{inspect reason}")
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
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
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        handler = FleetManagerPublisher.list_unit_states!(token, cluster.messaging_exchange_id)
        case RpcHandler.get_response(handler) do
          {:ok, states} ->
            if states == nil do
              conn
              |> put_status(:internal_server_error)
              |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
            else
              conn
              |> json states
            end
          {:error, reason} -> 
            Logger.error("Received the following error retrieving states:  #{inspect reason}")
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
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
  def unit_logs(conn, %{"etcd_token" => token, "machine_id" => _machine_id, "unit_name" => unit_name}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        handler = FleetManagerPublisher.unit_logs!(token, cluster.messaging_exchange_id, unit_name)
        case RpcHandler.get_response(handler) do
          {:ok, output} ->
            if output == nil do
              conn
              |> put_status(:internal_server_error)
              |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
            else
              conn
              |> json output
            end
          {:error, reason} -> 
            Logger.error("Received the following error retrieving unit log:  #{inspect reason}")
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
        end        
    end
  end
end