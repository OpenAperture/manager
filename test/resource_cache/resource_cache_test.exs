defmodule OpenAperture.Manager.ResourceCacheTest do
  use ExUnit.Case

  alias OpenAperture.Manager.ResourceCache

  test "get success" do
    call_count_pid = SimpleAgent.start! 0
    get = fn -> SimpleAgent.increment! call_count_pid; :my_val end
    assert ResourceCache.get(:broker, :test1, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert ResourceCache.get(:broker, :test1, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert ResourceCache.get(:broker, :test1, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
  end

  test "get invalid type" do
    assert_raise RuntimeError, "Invalid cache type", fn -> ResourceCache.get(:invalid_type, :a_key, &(&1)) end
  end

  test "clear success" do
    call_count_pid = SimpleAgent.start! 0
    get = fn -> SimpleAgent.increment! call_count_pid; :my_val end
    assert ResourceCache.get(:broker, :test2, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    assert ResourceCache.get(:broker, :test2, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 1
    ResourceCache.clear_local(:broker, :test2)
    assert ResourceCache.get(:broker, :test2, get) == :my_val
    assert SimpleAgent.get!(call_count_pid) == 2
  end

  test "clear invalid type" do
    assert_raise RuntimeError, "Invalid cache type", fn -> ResourceCache.clear_local(:invalid_type, :a_key) end
  end
end