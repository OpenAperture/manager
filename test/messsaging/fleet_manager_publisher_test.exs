defmodule OpenAperture.Manager.Messaging.FleetManagerPublisherTest do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Messaging.FleetManagerPublisher

  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.ConnectionOptions, as: AMQPConnectionOptions

  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.ConnectionPools  

  alias OpenAperture.Messaging.AMQP.RpcHandler

  setup do
    :ok
  end

  #==================================
  # handle_call({:execute_rpc_request}) tests

  test "handle_call({:execute_rpc_request}) success" do    
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(RpcHandler, [:passthrough])
    :meck.expect(RpcHandler, :start_link, fn _, _, _, _ -> {:ok, %{}} end)

    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> %OpenAperture.Messaging.Queue{name: ""} end)      

    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :resolve, fn _,_,_,_ -> %AMQPConnectionOptions{} end)

    request_body = %{}

    {:reply, response, returned_state} = FleetManagerPublisher.handle_call({:execute_rpc_request, request_body, 123}, nil, %{})
    assert elem(response,0) == :ok
    assert elem(response,1) != nil
  after
    :meck.unload(RpcHandler)
    :meck.unload(ConnectionPools)
    :meck.unload(QueueBuilder)
    :meck.unload(ConnectionOptionsResolver)    
  end

  test "handle_call({:execute_rpc_request}) failed" do    
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(RpcHandler, [:passthrough])
    :meck.expect(RpcHandler, :start_link, fn _, _, _, _ -> {:error, "bad news bears"} end)

    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> %OpenAperture.Messaging.Queue{name: ""} end)      

    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :resolve, fn _,_,_,_ -> %AMQPConnectionOptions{} end)

    request_body = %{}

    {:reply, response, returned_state} = FleetManagerPublisher.handle_call({:execute_rpc_request, request_body, 123}, nil, %{})
    assert elem(response,0) == :error
    assert elem(response,1) != nil
  after
    :meck.unload(RpcHandler)
    :meck.unload(ConnectionPools)
    :meck.unload(QueueBuilder)
    :meck.unload(ConnectionOptionsResolver)    
  end

  #==================================
  # list_machines! tests

  test "list_machines!" do    
    :meck.new(GenServer, [:unstick, :passthrough])
    :meck.expect(GenServer, :call, fn _,_ -> {:ok, %{}} end)

    request_body = %{}

    assert FleetManagerPublisher.list_machines!("123abc", 123) == %{}
  after
    :meck.unload(GenServer)
  end

  #==================================
  # list_units! tests

  test "list_units!" do    
    :meck.new(GenServer, [:unstick, :passthrough])
    :meck.expect(GenServer, :call, fn _,_ -> {:ok, %{}} end)

    request_body = %{}

    assert FleetManagerPublisher.list_units!("123abc", 123) == %{}
  after
    :meck.unload(GenServer)
  end  

  #==================================
  # list_unit_states! tests

  test "list_unit_states!" do    
    :meck.new(GenServer, [:unstick, :passthrough])
    :meck.expect(GenServer, :call, fn _,_ -> {:ok, %{}} end)

    request_body = %{}

    assert FleetManagerPublisher.list_unit_states!("123abc", 123) == %{}
  after
    :meck.unload(GenServer)
  end    

  #==================================
  # unit_logs! tests

  test "unit_logs!" do    
    :meck.new(GenServer, [:unstick, :passthrough])
    :meck.expect(GenServer, :call, fn _,_ -> {:ok, %{}} end)

    request_body = %{}

    assert FleetManagerPublisher.unit_logs!("123abc", 123, "test unit") == %{}
  after
    :meck.unload(GenServer)
  end    
end