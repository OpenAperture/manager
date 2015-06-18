defmodule DB.Models.SystemComponentRef.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.SystemComponentRef

  setup _context do

    on_exit _context, fn ->
      Repo.delete_all(SystemComponentRef)
    end
  end

  test "type is required" do
    changeset = SystemComponentRef.new(%{})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :type)
  end

  test "source_repo is required" do
    changeset = SystemComponentRef.new(%{type: "a_type"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :source_repo)
  end

  test "source_repo_git_ref is required" do
    changeset = SystemComponentRef.new(%{type: "a_type", source_repo: "https://github.com/test/test.git"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :source_repo_git_ref)
  end  

  test "auto_upgrade_enabled is required" do
    changeset = SystemComponentRef.new(%{type: "a_type", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :auto_upgrade_enabled)
  end

  test "success" do
    changeset = SystemComponentRef.new(%{type: "a_type", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true})
    assert changeset.valid?
  end    
end
