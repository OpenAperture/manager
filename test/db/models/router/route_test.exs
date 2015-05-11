defmodule DB.Models.Router.Route.Test do
  use ExUnit.Case

  alias OpenAperture.Manager.DB.Models.Router.Route

  test "authority_id, hostname, and port are required" do
    route = Route.new()

    refute route.valid?

    assert Keyword.has_key? route.errors, :authority_id
    assert Keyword.has_key? route.errors, :hostname
    assert Keyword.has_key? route.errors, :port
  end

  test "authority_id is required" do
    route = Route.new(%{hostname: "test", port: 1234})

    refute route.valid?

    assert Keyword.has_key? route.errors, :authority_id
  end

  test "hostname is required" do
    route = Route.new(%{authority_id: 1, port: 1234})

    refute route.valid?

    assert Keyword.has_key? route.errors, :hostname
  end

  test "port is required" do
    route = Route.new(%{authority_id: 1, hostname: "test"})

    refute route.valid?

    assert Keyword.has_key? route.errors, :port
  end

  test "hostname can't be blank" do
    route = Route.new(%{authority_id: 1, hostname: "", port: 1234})

    refute route.valid?

    assert Keyword.has_key? route.errors, :hostname
  end

  test "hostname can't be nil" do
    route = Route.new(%{authority_id: 1, hostname: nil, port: 1234})

    refute route.valid?

    assert Keyword.has_key? route.errors, :hostname
  end

  test "port can't be 0" do
    route = Route.new(%{authority_id: 1, hostname: "test", port: 0})

    refute route.valid?

    assert Keyword.has_key? route.errors, :port
  end

  test "port can't be < 0" do
    route = Route.new(%{authority_id: 1, hostname: "test", port: -1})

    refute route.valid?

    assert Keyword.has_key? route.errors, :port
  end

  test "port can't be > 65535" do
    route = Route.new(%{authority_id: 1, hostname: "test", port: 65536})

    refute route.valid?

    assert Keyword.has_key? route.errors, :port
  end
end