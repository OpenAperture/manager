defmodule OpenAperture.Manager.ResourceCache.CachedResourceTest do
  use ExUnit.Case

  alias OpenAperture.Manager.ResourceCache.CachedResource
  alias OpenAperture.Manager.DB.Models.MessagingBroker

  test "get success" do
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
    assert_raise RuntimeError, "Invalid cache type", fn -> CachedResource.get(:invalid_type, :a_key, &(&1)) end
  end

  test "clear success" do
    call_count_pid = SimpleAgent.start! 0
    get = fn -> SimpleAgent.increment! call_count_pid; :my_val end
    assert CachedResource.get(MessagingBroker, :test2, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert CachedResource.get(MessagingBroker, :test2, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    CachedResource.clear_local(MessagingBroker, :test2)
    assert CachedResource.get(MessagingBroker, :test2, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 2
  end

  test "clear invalid type" do
    assert_raise RuntimeError, "Invalid cache type", fn -> CachedResource.clear_local(:invalid_type, :a_key) end
  end
end