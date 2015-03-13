defmodule ProjectOmeletteManager.EtcdClusterController do
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
      cluster ->
        ## TODO: Once everything else is moved into this project...
        # cluster = CloudosBuildServer.Agents.EtcdCluster.create!(params["etcd_token"])
        # hosts = CloudosBuildServer.Agents.EtcdCluster.get_hosts(cluster)
        # if (hosts == nil) do
        #   json conn, 500, JSON.encode!(%{error: "Unable to determine if machines are available"})
        # else
        #   json conn, :ok, JSON.encode!(hosts)
        # end
        conn
        |> resp :not_implemented, ""
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
      cluster ->
        ## TODO: Once everything else is moved into this project...
        # cluster = CloudosBuildServer.Agents.EtcdCluster.create!(params["etcd_token"])
        # units = CloudosBuildServer.Agents.EtcdCluster.get_units(cluster)
        # if (units == nil) do
        #   json conn, 500, JSON.encode!(%{error: "Unable to determine if units are available"})
        # else
        #   json conn, :ok, JSON.encode!(units)
        # end
        conn
        |> resp :not_implemented, ""
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
      cluster ->
        ## TODO: Once everything else is moved into this project...
        # cluster = CloudosBuildServer.Agents.EtcdCluster.create!(params["etcd_token"])
        # states = CloudosBuildServer.Agents.EtcdCluster.get_units_state(cluster)
        # if (states == nil) do
        #   json conn, 500, JSON.encode!(%{error: "Unable to determine if states are available"})
        # else
        #   json conn, :ok, JSON.encode!(states)
        # end
        conn
        |> resp :not_implemented, ""
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
      cluster ->
        ## TODO: Once everything else is moved into this project...
        # cluster = CloudosBuildServer.Agents.EtcdCluster.create!(params["etcd_token"])
        # hosts = CloudosBuildServer.Agents.EtcdCluster.get_hosts(cluster)
        # units = CloudosBuildServer.Agents.EtcdCluster.get_units(cluster)

        # cond do
        #   hosts == nil -> json conn, 500, "Unable to determine if machines are available"
        #   units == nil -> json conn, 500, "Unable to determine if units are available"
        #   true ->
        #     unit = Enum.reduce(units, nil, fn(available_unit, requested_unit)->
        #       if requested_unit == nil && String.contains?(available_unit["name"], unit_name) do
        #         requested_unit = available_unit
        #       end
        #       requested_unit
        #     end)

        #     host = Enum.reduce(hosts, nil, fn(available_host, requested_host)->
        #       if requested_host == nil && String.contains?(available_host["id"], machine_id) do
        #         requested_host = available_host
        #       end
        #       requested_host
        #     end)

        #     cond do
        #       unit == nil -> json conn, 404, "Unit #{unit_name} does not exist"
        #       host == nil -> json conn, 404, "Host #{machine_id} does not exist"
        #       true ->
        #         case CloudosBuildServer.Agents.SystemdUnit.execute_journal_request([host], unit, false) do
        #           {:ok, output, error} ->
        #             Logger.info("Output:  #{output}")
        #             Logger.info("Error:  #{error}")
        #             json conn, :ok, output
        #           {:error, reason, _} -> json conn, 500, "Unable to retrieve logs:  #{reason}"
        #         end
        #     end
        # end
        conn
        |> resp :not_implemented, ""
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