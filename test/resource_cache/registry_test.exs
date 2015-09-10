defmodule OpenAperture.Manager.ResourceCache.RegistryTest do
  use ExUnit.Case

  alias OpenAperture.Manager.Messaging.ManagerQueue
  alias OpenAperture.Manager.ResourceCache.Registry

  setup do
    :ok
  after
    :meck.unload
    CacheWipe.wipe_all_caches
  end

  test "get populates when missing cache" do
    call_count_agent = SimpleAgent.start! 0
    :meck.new(ConCache)
    :meck.expect(ConCache, :start_link, fn _, arg2 ->
                                          SimpleAgent.increment! call_count_agent
                                          assert arg2 == [name: :test1]
                                        end)
    state = []
    {:reply, cache, state} = Registry.handle_call({:verify_started, :test1}, nil, state)
    assert cache == :test1
    assert state == [:test1]
    assert SimpleAgent.get!(call_count_agent) == 1
  end

  test "get does noting when cache already exists" do
    call_count_agent = SimpleAgent.start! 0
    :meck.new(ConCache)
    :meck.expect(ConCache, :start_link, fn _, arg2 ->
                                          SimpleAgent.increment! call_count_agent
                                        end)
    state = [:test1]
    {:reply, cache, state} = Registry.handle_call({:verify_started, :test1}, nil, state)
    assert cache == :test1
    assert state == [:test1]
    assert SimpleAgent.get!(call_count_agent) == 0
  end

end