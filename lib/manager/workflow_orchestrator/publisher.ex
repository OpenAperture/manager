#
# == publisher.ex
#
# This module contains the logic to publish messages to the WorkflowOrchestrator system module
#
require Logger

defmodule OpenAperture.Manager.WorkflowOrchestrator.Publisher do
	use GenServer

  @moduledoc """
  This module contains the logic to publish messages to the WorkflowOrchestrator system module
  """  

	alias OpenAperture.Messaging.AMQP.ConnectionOptions, as: AMQPConnectionOptions
	alias OpenAperture.Messaging.AMQP.QueueBuilder

	alias OpenAperture.Manager.Configuration

  alias OpenAperture.ManagerApi

	@connection_options nil
	use OpenAperture.Messaging

  @doc """
  Specific start_link implementation (required by the supervisor)

  ## Options

  ## Return Values

  {:ok, pid} | {:error, reason}
  """
  @spec start_link() :: {:ok, pid} | {:error, String.t()}   
  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Method to publish a hipchat notification

  ## Options

  The `workflow_struct` option is a DB.Models.Workflow to execute

  The `additional_options` option contains additional Workflow execution params, such as force_build

  ## Return Values

  :ok | {:error, reason}   
  """
  @spec execute_workflow(term, Map) :: :ok | {:error, String.t()}
  def execute_workflow(payload, additional_options \\ %{}) do
    payload = Map.merge(payload, additional_options)
    payload = Map.put(payload, :workflow_id, payload[:id])
  	GenServer.cast(__MODULE__, {:execute_workflow, payload})
  end

  @doc """
  Publishes to the WorkflowOrchestrator, via an asynchronous request to the `server`.

  This function returns `:ok` immediately, regardless of
  whether the destination node or server does exists, unless
  the server is specified as an atom.

  `handle_cast/2` will be called on the server to handle
  the request. In case the server is a node which is not
  yet connected to the caller one, the call is going to
  block until a connection happens. This is different than
  the behaviour in OTP's `:gen_server` where the message
  would be sent by another process, which could cause
  messages to arrive out of order.
  """
  @spec handle_cast({:execute_workflow, Map}, Map) :: {:noreply, Map}
  def handle_cast({:execute_workflow, payload}, state) do
    orchestration_queue = QueueBuilder.build(ManagerApi.get_api, "workflow_orchestration", Configuration.get_current_exchange_id)

    options = OpenAperture.Messaging.ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, Configuration.get_current_broker_id)
		case publish(options, orchestration_queue, payload) do
			:ok -> Logger.debug("Successfully published to WorkflowOrchestrator")
			{:error, reason} -> Logger.error("Failed to publish to WorkflowOrchestrator:  #{inspect reason}")
		end
    {:noreply, state}
  end
end