defmodule DB.Models.Router.DeletedAuthority.Test do
  use ExUnit.Case

  alias OpenAperture.Manager.DB.Models.Router.DeletedAuthority

  test "hostname and port are required" do
    deleted_authority = DeletedAuthority.new()

    refute deleted_authority.valid?

    assert Keyword.has_key? deleted_authority.errors, :hostname
    assert Keyword.has_key? deleted_authority.errors, :port
  end

  test "hostname is required" do
    deleted_authority = DeletedAuthority.new(%{port: 1234})

    refute deleted_authority.valid?

    assert Keyword.has_key? deleted_authority.errors, :hostname
  end

  test "port is required" do
    deleted_authority = DeletedAuthority.new(%{hostname: "test"})

    refute deleted_authority.valid?

    assert Keyword.has_key? deleted_authority.errors, :port
  end
end