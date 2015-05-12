defmodule OpenAperture.Manager.Controllers.Router.Util.Test do
  use ExUnit.Case
  doctest OpenAperture.Manager.Controllers.Router.Util

  import OpenAperture.Manager.Controllers.Router.Util

  test "parses non-urlencoded value" do
    assert parse_hostspec("test:80") == {:ok, "test", 80}
  end

  test "parses uppercase urlencoded value" do
    assert parse_hostspec("test%3A80") == {:ok, "test", 80}
  end

  test "parses lowercase urlencoded value" do
    assert parse_hostspec("test%3a80") == {:ok, "test", 80}
  end

  test "returns :error if value can't be parsed" do
    assert parse_hostspec("test^9999") == :error
  end
end