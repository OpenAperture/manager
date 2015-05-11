defmodule DB.Models.Router.Authority.Test do
  use ExUnit.Case

  alias OpenAperture.Manager.DB.Models.Router.Authority

  test "hostname and port are required" do
    authority = Authority.new()

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :hostname
    assert Keyword.has_key? authority.errors, :port
  end

  test "hostname is required" do
    authority = Authority.new(%{port: 1234})

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :hostname
  end

  test "port is required" do
    authority = Authority.new(%{hostname: "test"})

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :port
  end

  test "hostname can't be blank" do
    authority = Authority.new(%{hostname: "", port: 1234})

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :hostname
  end

  test "hostname can't be nil" do
    authority = Authority.new(%{hostname: nil, port: 1234})

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :hostname
  end

  test "port can't be 0" do
    authority = Authority.new(%{hostname: "test", port: 0})

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :port
  end

  test "port can't be < 0" do
    authority = Authority.new(%{hostname: "test", port: -1})

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :port
  end

  test "port can't be > 65535" do
    authority = Authority.new(%{hostname: "test", port: 65536})

    refute authority.valid?

    assert Keyword.has_key? authority.errors, :port
  end
end