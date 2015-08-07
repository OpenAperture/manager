require Logger

defmodule OpenAperture.Manager.Messaging.FleetManagerPublisher do
  use GenServer

  alias OpenAperture.Messaging.ConnectionOptionsResolver
	alias OpenAperture.Messaging.AMQP.QueueBuilder

	alias OpenAperture.ManagerApi
	alias OpenAperture.Messaging.RpcRequest

	alias OpenAperture.Manager.Configuration

  @moduledoc """
  This module contains the GenServer for publishing RPC messages to the FleetManager
  """

  @connection_options nil
  use OpenAperture.Messaging

  @doc """
  Method to start a publisher

  ## Return Values

  {:ok, pid} | {:error, reason}
  """
  @spec start_link :: {:ok, pid} | {:error, String.t()}  
  def start_link do
    Logger.debug("Starting FleetManagerPublisher...")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end  

  @doc """
  Method to retrieve the machines in a Cluster

  ## Options

  The `etcd_token` option represents the EtcdCluster token

  The `cluster_exchange_id` represents the messaging_exchange_id associated with the cluster

  ## Return Values

  RpcHandler pid
  """
  @spec list_machines!(String.t(), term) :: pid
	def list_machines!(etcd_token, cluster_exchange_id) do
		request_body = %{
        etcd_token: etcd_token,
        action: :list_machines
    }

    case GenServer.call(__MODULE__, {:execute_rpc_request, request_body, cluster_exchange_id}) do
      {:ok, handler} -> handler
      {:error, reason} -> raise reason
    end
	end

  @doc """
  Method to retrieve the units in a Cluster

  ## Options

  The `etcd_token` option represents the EtcdCluster token

  The `cluster_exchange_id` represents the messaging_exchange_id associated with the cluster

  ## Return Values

  RpcHandler pid
  """
  @spec list_units!(String.t(), term) :: pid
  def list_units!(etcd_token, cluster_exchange_id) do
    request_body = %{
        etcd_token: etcd_token,
        action: :list_units
    }

    case GenServer.call(__MODULE__, {:execute_rpc_request, request_body, cluster_exchange_id}) do
      {:ok, handler} -> handler
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Method to retrieve the unit states in a Cluster

  ## Options

  The `etcd_token` option represents the EtcdCluster token

  The `cluster_exchange_id` represents the messaging_exchange_id associated with the cluster

  ## Return Values

  RpcHandler pid
  """
  @spec list_unit_states!(String.t(), term) :: pid
  def list_unit_states!(etcd_token, cluster_exchange_id) do
    request_body = %{
        etcd_token: etcd_token,
        action: :list_unit_states
    }

    case GenServer.call(__MODULE__, {:execute_rpc_request, request_body, cluster_exchange_id}) do
      {:ok, handler} -> handler
      {:error, reason} -> raise reason
    end
  end
    
  @doc """
  Method to retrieve unit logs for a particular Unit in a cluster

  ## Options

  The `etcd_token` option represents the EtcdCluster token

  The `cluster_exchange_id` represents the messaging_exchange_id associated with the cluster

  The `unit_name` option represents the name of the unit for which logs should be retrieved

  ## Return Values

  RpcHandler pid
  """
  @spec unit_logs!(String.t(), term, String.t) :: pid   
  def unit_logs!(etcd_token, cluster_exchange_id, unit_name) do
    request_body = %{
        etcd_token: etcd_token,
        action: :unit_logs,
        action_parameters: %{
          unit_name: unit_name
        }
    }

    case GenServer.call(__MODULE__, {:execute_rpc_request, request_body, cluster_exchange_id}) do
      {:ok, handler} -> handler
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Method to retrieve detailed information about nodes in a cluster

  ## Options

  The `cluster_exchange_id` represents the messaging_exchange_id associated with the cluster

  The `nodes` option represents a list of IPs/hostnames for which information should be retrieved

  ## Return Values

  RpcHandler pid
  """
  @spec node_info!(term, List) :: pid   
  def node_info!(cluster_exchange_id, nodes) do
    request_body = %{
        action: :node_info,
        action_parameters: %{
          nodes: nodes
        }
    }

    case GenServer.call(__MODULE__, {:execute_rpc_request, request_body, cluster_exchange_id}) do
      {:ok, handler} -> handler
      {:error, reason} -> raise reason
    end    
  end  

  @doc """
  Method to restart a Unit

  ## Options

  The `etcd_token` option represents the EtcdCluster token

  The `cluster_exchange_id` represents the messaging_exchange_id associated with the cluster

  The `unit_name` option represents the name of the unit for which logs should be retrieved

  ## Return Values

  RpcHandler pid
  """
  @spec restart_unit!(String.t(), term, String.t) :: pid   
  def restart_unit!(etcd_token, cluster_exchange_id, unit_name) do
    request_body = %{
        etcd_token: etcd_token,
        action: :restart_unit,
        action_parameters: %{
          unit_name: unit_name
        }
    }

    case GenServer.call(__MODULE__, {:execute_rpc_request, request_body, cluster_exchange_id}) do
      {:ok, handler} -> handler
      {:error, reason} -> raise reason
    end
  end

  @spec handle_call({:execute_rpc_request, Map, term}, term, Map) :: {:reply, pid, Map}
  def handle_call({:execute_rpc_request, request_body, cluster_exchange_id}, _from, state) do
    request = %RpcRequest{
      status: :not_started,
      request_body: request_body
    }

    fleet_manager_queue = QueueBuilder.build(ManagerApi.get_api, "fleet_manager", cluster_exchange_id)

    connection_options = ConnectionOptionsResolver.resolve(
      ManagerApi.get_api, 
      Configuration.get_current_broker_id,
      Configuration.get_current_exchange_id,
      cluster_exchange_id
    )

    {:reply, publish_rpc(connection_options, fleet_manager_queue, ManagerApi.get_api, request), state}
  end
end