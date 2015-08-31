defmodule OpenAperture.Manager.ResourceCacheQueueBroadcasterTest do
  use ExUnit.Case

  alias OpenAperture.Manager.ResourceCache
  alias OpenAperture.Manager.ResourceCacheQueueBroadcaster

  setup do
    :ok
  after
    :meck.unload
  end

  test "broadcast" do
    system_components = [%{type: "manager", messaging_exchange_id: 5},
                         %{type: "builder", messaging_exchange_id: 5},
                         %{type: "manager", messaging_exchange_id: 3},
                         %{type: "deployer", messaging_exchange_id: 4},
                         %{type: "manager", messaging_exchange_id: 5}]
    :meck.new(ResourceCache)
    :meck.expect(ResourceCache, :get, fn type, key, _ ->
                                        case type do
                                          :system_component -> system_components
                                          :exchange_cache_queues -> {String.to_atom("queue_#{key}"), String.to_atom("options_#{key}")}
                                        end
                                      end)
    {:ok, publish_queues_pid} = Agent.start_link(fn -> [] end)
    :meck.new(ResourceCacheQueueBroadcaster, [:passthrough])
    :meck.expect(ResourceCacheQueueBroadcaster, :publish, fn _options, queue, payload ->
                                            assert payload == %{type: :my_type, key: 5}
                                            Agent.update(publish_queues_pid, fn a -> a ++ [queue] end)
                                          end)
    ResourceCacheQueueBroadcaster.broadcast_cache_clear(:my_type, 5)
    published_queues = Agent.get(publish_queues_pid, &(&1))
    assert published_queues == [:queue_3, :queue_5]
  end

end