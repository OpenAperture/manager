defmodule DB.Models.CloudProvider.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.CloudProvider

  setup _context do

    on_exit _context, fn ->
      Repo.delete_all(CloudProvider)
    end
  end

  test "cloud_provider name is required" do
    changeset = CloudProvider.new(%{:type => "a_type", :configuration => "myconfig"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "cloud_provider type is required" do
    changeset = CloudProvider.new(%{:name => "a_name", :configuration => "myconfig"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :type)
  end

  test "cloud_provider configuration is required" do
    changeset = CloudProvider.new(%{:type => "a_type", :name => "a_name"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :configuration)
  end
end
