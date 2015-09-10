defmodule OpenAperture.Manager.ResourceCache.PublisherTest do
  use ExUnit.Case

  alias OpenAperture.Manager.ResourceCache.CachedResource
  alias OpenAperture.Manager.ResourceCache.Publisher
  alias OpenAperture.Manager.DB.Models.SystemComponent

  setup do
    :ok
  after
    :meck.unload
    CacheWipe.wipe_all_caches
  end

  test "publish_to_queue" do
    system_components = [%{type: "manager", messaging_exchange_id: 5},
                         %{type: "builder", messaging_exchange_id: 5},
                         %{type: "manager", messaging_exchange_id: 3},
                         %{type: "deployer", messaging_exchange_id: 4},
                         %{type: "manager", messaging_exchange_id: 5}]
    :meck.new(CachedResource)
    :meck.expect(CachedResource, :get, fn SystemComponent, _, _ -> system_components end)
    {:ok, publish_queues_pid} = Agent.start_link(fn -> [] end)
    :meck.new(Publisher, [:passthrough])
    :meck.expect(Publisher, :publish, fn _options, queue, payload ->
                                            assert payload == %{type: :my_type, key: 5}
                                            Agent.update(publish_queues_pid, fn a -> a ++ [queue] end)
                                          end)
    :meck.expect(Publisher, :get_exchange_queue, fn key -> {String.to_atom("queue_#{key}"), String.to_atom("options_#{key}")} end)
    Publisher.cache_clear(:my_type, 5)
    published_queues = Agent.get(publish_queues_pid, &(&1))
    assert Enum.sort(published_queues) == Enum.sort([:queue_3, :queue_5])
  end

end