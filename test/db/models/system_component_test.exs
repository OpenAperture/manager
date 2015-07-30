defmodule DB.Models.SystemComponent.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Manager.DB.Models.MessagingExchange

  setup _context do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "test exchange"}))

    on_exit _context, fn ->
      Repo.delete_all(SystemComponent)
      Repo.delete_all(MessagingExchange)
    end

    {:ok, [exchange: exchange]}
  end

  test "messaging_exchange_id is required" do
    changeset = SystemComponent.new(%{})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :messaging_exchange_id)
  end

  test "messaging_exchange_id is invalid" do
    changeset = SystemComponent.new(%{messaging_exchange_id: 1234567890})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :messaging_exchange_id)
  end

  test "type is required", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :type)
  end

  test "source_repo is optional", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "a_type"})
    refute changeset.valid?
    refute Keyword.has_key?(changeset.errors, :source_repo)
  end

  test "source_repo_git_ref is optional", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "a_type", source_repo: "https://github.com/test/test.git"})
    refute changeset.valid?
    refute Keyword.has_key?(changeset.errors, :source_repo_git_ref)
  end

  test "deployment_repo is required", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "a_type", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :deployment_repo)
  end

  test "deployment_repo_git_ref is required", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "a_type", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", deployment_repo: "https://github.com/test/test_deploy.git"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :deployment_repo_git_ref)
  end

  test "success", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "a_type", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", deployment_repo: "https://github.com/test/test_deploy.git", deployment_repo_git_ref: "234xyz", upgrade_strategy: to_string(:manual)})
    assert changeset.valid?
  end    

  test "status optional", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "a_type", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", deployment_repo: "https://github.com/test/test_deploy.git", deployment_repo_git_ref: "234xyz", upgrade_strategy: to_string(:manual), status: to_string(:available)})
    assert changeset.valid?
  end    

  test "upgrade_status optional", context do
    changeset = SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "a_type", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", deployment_repo: "https://github.com/test/test_deploy.git", deployment_repo_git_ref: "234xyz", upgrade_strategy: to_string(:manual), upgrade_status: to_string(:available)})
    assert changeset.valid?
  end 
end