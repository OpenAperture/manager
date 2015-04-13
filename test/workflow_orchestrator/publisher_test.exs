defmodule OpenAperture.Manager.WorkflowOrchestrator.PublisherTest do
  use ExUnit.Case

  alias OpenAperture.Manager.WorkflowOrchestrator.Publisher
  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.ConnectionOptions, as: AMQPConnectionOptions

  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.ConnectionPool
  alias OpenAperture.Messaging.AMQP.ConnectionPools

  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.DB.Models.Workflow, as: WorkflowDB

  setup_all _context do
    on_exit _context, fn ->
      Repo.delete_all(WorkflowDB)
    end    
    :ok
  end

  #=========================
  # handle_cast({:hipchat, payload}) tests

  test "handle_cast({:execute_workflow, payload}) - success" do
  	:meck.new(ConnectionPools, [:passthrough])
  	:meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

  	:meck.new(ConnectionPool, [:passthrough])
  	:meck.expect(ConnectionPool, :publish, fn _, _, _, _ -> :ok end)

    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> %OpenAperture.Messaging.Queue{name: ""} end)      

    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _, _ -> %AMQPConnectionOptions{} end)

  	state = %{
  	}

    workflow_id = "#{UUID.uuid1()}"
    raw_workflow_id = (workflow_id |> UUID.info)[:binary]    
    workflow = Repo.insert(WorkflowDB.new(%{id: raw_workflow_id}))

    workflow_map = List.first(OpenAperture.Manager.Controllers.Workflows.convert_raw_workflows([workflow]))
    payload = Map.merge(workflow_map, %{force_build: true})
    assert Publisher.handle_cast({:execute_workflow, payload}, state) == {:noreply, state}
  after
  	:meck.unload(ConnectionPool)
  	:meck.unload(ConnectionPools)
    :meck.unload(QueueBuilder)
    :meck.unload(ConnectionOptionsResolver)
  end
end
