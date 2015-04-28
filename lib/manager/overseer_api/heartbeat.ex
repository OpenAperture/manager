require Logger

defmodule OpenAperture.Manager.OverseerApi.Heartbeat do
  use GenServer

  @connection_options nil
  use OpenAperture.Messaging

  alias OpenAperture.Manager.OverseerApi.ModuleRegistration
  alias OpenAperture.Manager.Configuration

  alias OpenapertureManager.Repo
  require Repo

  alias OpenAperture.ManagerApi

  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.QueueBuilder  

  @moduledoc """
  This module contains the GenServer for the Manager system module to interact with the Overseer system module
  """  

  @doc """
  Specific start_link implementation

  ## Return Values

  {:ok, pid} | {:error, reason}
  """
  @spec start_link() :: {:ok, pid} | {:error, String.t()}  
  def start_link() do
    Logger.debug("[Heartbeat] Starting...")

    case GenServer.start_link(__MODULE__, %{}, name: __MODULE__) do
      {:ok, pid} ->
        if Application.get_env(:openaperture_manager_overseer_api, :autostart, true) do
          GenServer.cast(pid, {:publish})
        end

        Agent.start_link(fn -> [] end, name: HeartbeatWorkload)
        {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Method to publish Events to the Overseer

  ## Option Values

  The `event` module represents the Event to publish

  ## Return Value

  :ok
  """
  @spec set_workload(List) :: :ok
  def set_workload(workload) do
    Agent.update(HeartbeatWorkload, fn _ -> workload end)
  end

  @doc """
  GenServer callback for handling the :publish_event event.  This method
  will publish a "heartbeat" (StatuEvent) every 30 seconds

  {:noreply, state}
  """
  @spec handle_cast({:publish}, Map) :: {:noreply, Map}
  def handle_cast({:publish}, state) do
    :timer.sleep(30000)
    Logger.debug("[Heartbeat] Heartbeat...")
    publish_status_event(state)
    GenServer.cast(__MODULE__, {:publish})
    {:noreply, state}
  end

  def publish_status_event(state) do
    workload = Agent.get(HeartbeatWorkload, fn workload -> workload end)
    workload = if workload == nil do
      []
    else
      workload
    end

    module = ModuleRegistration.get_module

    payload = %{
      hostname: module[:hostname],
      type: module[:type],
      workload: workload,
      status: :active,
      event_type: :status
    }
    
    options = ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, Configuration.get_current_broker_id)
    event_queue = QueueBuilder.build(ManagerApi.get_api, "system_modules", Configuration.get_current_exchange_id)

    case publish(options, event_queue, payload) do
      :ok -> Logger.debug("[Publisher] Successfully published Overseer :status event")
      {:error, reason} -> Logger.error("[Publisher] Failed to publish Overseer :status event:  #{inspect reason}")
    end
    {:noreply, state}
  end
end