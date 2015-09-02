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

  @sendable_fields [:id, :etcd_token, :name, :hosting_provider_id, :allow_docker_builds, :messaging_exchange_id, :inserted_at, :updated_at]

  @sendable_fields_products [:id, :name, :updated_at, :inserted_at]

  @doc """
  List all Etcd Clusters the system knows about.
  """
  def swaggerdoc_index, do: %{
    description: "Retrieve all EtcdClusters",
    response_schema: %{"type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.EtcdCluster"}},
    parameters: []
  }      
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t
  def index(conn, params) do
    # TODO: Pagination?
    clusters = case params["allow_docker_builds"] do
      true -> Repo.all(EtcdClusterQuery.get_docker_build_clusters)
      "true" ->  Repo.all(EtcdClusterQuery.get_docker_build_clusters)
      _ -> Repo.all(EtcdCluster)
    end

    json conn, FormatHelper.to_sendable(clusters, @sendable_fields)
  end

  @doc """
  Retrieve a specific Etcd Cluster instance, specified by its etcd token.
  """
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific EtcdCluster",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.EtcdCluster"},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t
  def show(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster -> json conn, FormatHelper.to_sendable(cluster, @sendable_fields)
    end
  end

  @doc """
  Register an EtcdCluster (create a new db reference)
  """
  def swaggerdoc_register, do: %{
    description: "Register an EtcdCluster with OpenAperture",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.EtcdCluster"},
    parameters: [%{
      "name" => "type",
      "in" => "body",
      "description" => "The new EtcdCluster",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.EtcdCluster"}
    }]
  } 
  @spec register(Plug.Conn.t, [any]) :: Plug.Conn.t
  def register(conn, params) do
    cluster = EtcdCluster.new(%{:etcd_token => params["etcd_token"], 
                                :hosting_provider_id => params["hosting_provider_id"],
                                :allow_docker_builds => params["allow_docker_builds"],
                                :messaging_exchange_id => params["messaging_exchange_id"],
                                :name => params["name"]})
    if cluster.valid? do
      try do
        cluster = Repo.insert!(cluster)
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
  def swaggerdoc_destroy, do: %{
    description: "Delete an EtcdCluster" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    }]
  }  
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def destroy(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        try do
          EtcdCluster.destroy(cluster)
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
  def swaggerdoc_products, do: %{
    description: "Retrieve all products associated with the EtcdCluster",
    response_schema: %{"type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Product"}},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    }]
  }    
  @spec products(Plug.Conn.t, [any]) :: Plug.Conn.t
  def products(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil -> resp conn, :not_found, ""
      etcd_cluster -> json conn, FormatHelper.to_sendable(Repo.all(ProductClusterQuery.get_products_for_cluster(etcd_cluster.id)), @sendable_fields_products)        
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
  def swaggerdoc_machines, do: %{
    description: "Retrieve all machines associated with the EtcdCluster",
    response_schema: %{"title" => "FleetApi.Machines", "type": "array", "items": %{
      "description" => "A Fleet Machine",
      "type" => "object",
      "required" => ["id","primaryIP","metadata"],
      "properties" => %{
        "id" => %{"type" => "string", "description" => "Fleet Machine identifier"},
        "primaryIP" => %{"type" => "string", "description" => "The IP address of the Machine"},
        "metadata" => %{"type" => "array","items" => %{"type" => "string"}, "description" => "Metadata associated with the Machine"},
      }
    }},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    }]
  }
  @spec machines(Plug.Conn.t, [any]) :: Plug.Conn.t  
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
  def swaggerdoc_units, do: %{
    description: "Retrieve all Fleet units associated with the EtcdCluster",
    response_schema: %{"type": "array", "items": %{
      "description" => "A Fleet Unit",
      "type" => "object",
      "required" => ["name","options","desiredState","currentState","machineID"],
      "properties" => %{
        "name" => %{"type" => "string", "description" => "Name of the Unit"},
        "options" => %{"type" => "array","items" => %{"type" => "string"}, "description" => "Fleet UnitOptions"},
        "desiredState" => %{"type" => "string", "description" => "The systemd desired state"},
        "currentState" => %{"type" => "string", "description" => "The systemd current state"},
        "machineID" => %{"type" => "string", "description" => "The Fleet machine identifier hosting the unit"}
      }
    }},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    }]
  }
  @spec units(Plug.Conn.t, [any]) :: Plug.Conn.t   
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
  def swaggerdoc_units_state, do: %{
    description: "Retrieve all states of all Fleet Units",
    response_schema: %{"type": "array", "items": %{
      "description" => "A Fleet Machine",
      "type" => "object",
      "required" => ["name","hash","machineID", "systemdLoadState", "systemdActiveState", "systemdSubState"],
      "properties" => %{
        "name" => %{"type" => "string", "description" => "Name of the Fleet Unit"},
        "hash" => %{"type" => "string", "description" => "SHA1 hash of underlying unit file"},
        "machineID" => %{"type" => "string", "description" => "The Fleet machine identifier hosting the unit"},
        "systemdLoadState" => %{"type" => "string", "description" => "Systemd load state"},
        "systemdActiveState" => %{"type" => "string", "description" => "Systemd active state"},
        "systemdSubState" => %{"type" => "string", "description" => "Systemd sub state"},
      }
    }},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    }]
  }
  @spec units_state(Plug.Conn.t, [any]) :: Plug.Conn.t    
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
  def swaggerdoc_unit_logs, do: %{
    description: "Retrieve the log files for a specific Fleet Unit",
    response_schema: %{"name" => %{"type" => "string", "description" => "Log file output"}},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "machine_id",
      "in" => "path",
      "description" => "Fleet Machine identifier",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "unit_name",
      "in" => "path",
      "description" => "URL-encoded Fleet Unit name",
      "required" => true,
      "type" => "string"
    }]
  }
  @spec unit_logs(Plug.Conn.t, [any]) :: Plug.Conn.t    
  def unit_logs(conn, %{"etcd_token" => token, "machine_id" => _machine_id, "unit_name" => unit_name}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        handler = FleetManagerPublisher.unit_logs!(token, cluster.messaging_exchange_id, URI.decode(unit_name))
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

  @doc """
  GET /clusters/:etcd_token/nodes - Retrieve node information about all machines associated with the etcd_token

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Plug.Conn
  """
  def swaggerdoc_node_info, do: %{
    description: "Retrieve information about the Fleet Machines (nodes)",
    response_schema: %{"type": "array", "items": %{
      "description" => "A Fleet Machine",
      "type" => "object",
      "required" => ["docker_disk_space_percent", "coreos_version", "docker_version"],
      "properties" => %{
        "docker_disk_space_percent" => %{"type" => "integer", "description" => "The percentage of free disk space for the /var/lib/docker directory"},
        "coreos_version" => %{"type" => "string", "description" => "A dump of the CoreOS version information"},
        "docker_version" => %{"type" => "string", "description" => "A dump of the docker version information"},
      }
    }},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    }]
  }
  @spec node_info(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def node_info(conn, %{"etcd_token" => token}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->
        handler = FleetManagerPublisher.list_machines!(token, cluster.messaging_exchange_id)
        case RpcHandler.get_response(handler) do
          {:ok, nil} ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
          {:ok, []} ->
            conn
            |> json %{}
          {:ok, machines} ->
            get_node_info(conn, cluster.messaging_exchange_id, machines)
          {:error, reason} -> 
            Logger.error("Received the following error retrieving hosts:  #{inspect reason}")
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
        end
    end
  end

  defp get_node_info(conn, messaging_exchange_id, machines) do
    nodes = Enum.reduce machines, [], fn(machine, nodes) -> 
      nodes ++ [machine["primaryIP"]]
    end

    handler = FleetManagerPublisher.node_info!(messaging_exchange_id, nodes)
    case RpcHandler.get_response(handler) do
      {:ok, node_info} ->
        if node_info == nil do
          conn
          |> put_status(:internal_server_error)
          |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
        else
          conn
          |> json node_info
        end
      {:error, reason} -> 
        Logger.error("Received the following error retrieving node_info:  #{inspect reason}")
        conn
        |> put_status(:internal_server_error)
        |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
    end  
  end

  @doc """
  GET /clusters/:etcd_token/machines/:machine_id/units/:unit_name/restart - Retrieve associated units' state

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Plug.Conn
  """
  def swaggerdoc_restart_unit, do: %{
    description: "Restart a Fleet Unit",
    response_schema: %{"name" => %{"type" => "string", "description" => "Restart output"}},
    parameters: [%{
      "name" => "etcd_token",
      "in" => "path",
      "description" => "EtcdCluster token",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "machine_id",
      "in" => "path",
      "description" => "Fleet Machine identifier",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "unit_name",
      "in" => "path",
      "description" => "URL-encoded Fleet Unit name",
      "required" => true,
      "type" => "string"
    }]
  }
  @spec restart_unit(Plug.Conn.t, [any]) :: Plug.Conn.t   
  def restart_unit(conn, %{"etcd_token" => token, "machine_id" => _machine_id, "unit_name" => unit_name}) do
    case EtcdClusterQuery.get_by_etcd_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "EtcdCluster")
      cluster ->        
        handler = FleetManagerPublisher.restart_unit!(token, cluster.messaging_exchange_id, URI.decode(unit_name))
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
            Logger.error("Received the following error restarting unit log:  #{inspect reason}")
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "EtcdCluster")
        end        
    end
  end
end