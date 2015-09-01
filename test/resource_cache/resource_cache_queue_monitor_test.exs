defmodule OpenAperture.Manager.ResourceCache.QueueSubscriberTest do
  use ExUnit.Case

  alias OpenAperture.Manager.Messaging.ManagerQueue
  alias OpenAperture.Manager.ResourceCache.CachedResource
  alias OpenAperture.Manager.ResourceCache.QueueSubscriber
  alias OpenAperture.Manager.DB.Models.MessagingBroker

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
    assert QueueSubscriber.init(:ok) == {:ok, nil}
    assert SimpleAgent.get!(call_count_pid) == 1
  end

  test "clear_cache success" do
    call_count_pid = SimpleAgent.start! 0
    get = fn -> SimpleAgent.increment! call_count_pid; :my_val end
    assert CachedResource.get(MessagingBroker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert CachedResource.get(MessagingBroker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    QueueSubscriber.clear_cache(%{type: MessagingBroker, key: :test3})
    assert CachedResource.get(MessagingBroker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 2
    QueueSubscriber.clear_cache(%{type: MessagingBroker, key: :test999})
    assert CachedResource.get(MessagingBroker, :test3, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 2
  end
end