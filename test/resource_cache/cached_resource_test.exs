defmodule OpenAperture.Manager.ResourceCache.CachedResourceTest do
  use ExUnit.Case

  alias OpenAperture.Manager.ResourceCache.CachedResource
  alias OpenAperture.Manager.ResourceCache.Publisher
  alias OpenAperture.Manager.DB.Models.MessagingBroker

  setup do
    :ok
  after
    :meck.unload
    CacheWipe.wipe_all_caches
  end

  test "get success" do
    :meck.new(CachedResource, [:passthrough])
    :meck.expect(CachedResource, :cache_disabled, fn -> false end)
    call_count_pid = SimpleAgent.start! 0
    get = fn -> SimpleAgent.increment! call_count_pid; :my_val end
    assert CachedResource.get(MessagingBroker, :test1, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert CachedResource.get(MessagingBroker, :test1, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert CachedResource.get(MessagingBroker, :test1, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
  end

  test "get invalid type" do
    :meck.new(CachedResource, [:passthrough])
    :meck.expect(CachedResource, :cache_disabled, fn -> false end)
    assert_raise RuntimeError, "Invalid cache type: invalid_type", fn -> CachedResource.get(:invalid_type, :a_key, &(&1)) end
  end

  test "clear calls publisher" do
    :meck.new(CachedResource, [:passthrough])
    :meck.expect(CachedResource, :cache_disabled, fn -> false end)
    call_count_pid = SimpleAgent.start! 0
    :meck.new(Publisher)
    :meck.expect(Publisher, :cache_clear, fn type, key ->
                                            assert type == MessagingBroker
                                            assert key == :test2
                                            SimpleAgent.increment!(call_count_pid)
                                          end)
    CachedResource.clear(MessagingBroker, :test2)
    assert SimpleAgent.get!(call_count_pid) == 1
  end

  test "clear invalid type" do
    :meck.new(CachedResource, [:passthrough])
    :meck.expect(CachedResource, :cache_disabled, fn -> false end)
    assert_raise RuntimeError, "Invalid cache type: invalid_type", fn -> CachedResource.clear(:invalid_type, :a_key) end
  end
end