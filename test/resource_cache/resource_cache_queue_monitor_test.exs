defmodule OpenAperture.Manager.ResourceCacheQueueMonitorTest do
  use ExUnit.Case

  alias OpenAperture.Manager.Messaging.ManagerQueue
  alias OpenAperture.Manager.ResourceCache
  alias OpenAperture.Manager.ResourceCacheQueueMonitor

  setup do
    :ok
  after
    :meck.unload
  end

  test "init" do
    call_count_pid = SimpleAgent.start! 0
    :meck.new(ManagerQueue, [:passthrough])
    :meck.expect(ManagerQueue, :build_and_subscribe, fn queue_name, _fun ->
                        assert queue_name == "cache"
                        SimpleAgent.increment! call_count_pid
                      end)
    assert ResourceCacheQueueMonitor.init(:ok) == {:ok, nil}
    assert SimpleAgent.get!(call_count_pid) == 1
  end

  test "clear_cache success" do
    call_count_pid = SimpleAgent.start! 0
    get = fn -> SimpleAgent.increment! call_count_pid; :my_val end
    assert ResourceCache.get(:broker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert ResourceCache.get(:broker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    ResourceCacheQueueMonitor.clear_cache(%{type: :broker, key: :test3})
    assert ResourceCache.get(:broker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 2
    ResourceCacheQueueMonitor.clear_cache(%{type: :broker, key: :test999})
    assert ResourceCache.get(:broker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 2
  end
end