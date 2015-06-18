defmodule OpenAperture.Manager.Controllers.SystemComponentTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Plugs.Authentication

  require Repo
  import Ecto.Query  

  setup_all do
    exchange = Repo.insert(MessagingExchange.new(%{name: "test exchange"}))

    :meck.new(Authentication, [:passthrough])
    :meck.expect(Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn ->
      :meck.unload

      Repo.delete_all(SystemComponent)
      Repo.delete_all(MessagingExchange)
    end

    {:ok, [exchange: exchange]}
  end

  setup do
    Repo.delete_all(SystemComponent)
    :ok
  end

  @endpoint OpenAperture.Manager.Endpoint

  # ==================================
  # index tests

  test "index - no components" do
    conn = get conn(), "/system_components"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index - components", context do
    Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))
    Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = get conn(), "/system_components"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2
  end

  # ==================================
  # show tests

  test "show - invalid component" do
    conn = get conn(), "/system_components/1234567890"
    assert conn.status == 404
  end

  test "show - valid component", context do
    component = Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = get conn(), "/system_components/#{component.id}"
    assert conn.status == 200

    returned_component = Poison.decode!(conn.resp_body)
    assert returned_component != nil
    assert returned_component["type"] == component.type
    assert returned_component["source_repo"] == component.source_repo
    assert returned_component["source_repo_git_ref"] == component.source_repo_git_ref
    assert returned_component["deployment_repo"] == component.deployment_repo
    assert returned_component["deployment_repo_git_ref"] == component.deployment_repo_git_ref    
    assert returned_component["upgrade_strategy"] == component.upgrade_strategy
  end  

  # ==================================
  # create tests

  test "create - conflict", context do
    Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = post conn(), "/system_components", %{"messaging_exchange_id" => context[:exchange].id, "type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "upgrade_strategy" => "manaul", "deployment_repo"=> "https://github.com/test/test.git", "deployment_repo_git_ref"=> "123abc"}
    assert conn.status == 409
  end

  test "create - bad request", context do
    conn = post conn(), "/system_components", %{}
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "create - internal server error", context do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :insert, fn _ -> raise "bad news bears" end)

    conn = post conn(), "/system_components", %{"messaging_exchange_id" => context[:exchange].id, "type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "upgrade_strategy" => "manaul", "deployment_repo"=> "https://github.com/test/test.git", "deployment_repo_git_ref"=> "123abc"}
    
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success", context do
    conn = post conn(), "/system_components", %{"messaging_exchange_id" => context[:exchange].id, "type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "upgrade_strategy" => "manaul", "deployment_repo"=> "https://github.com/test/test.git", "deployment_repo_git_ref"=> "123abc"}
    
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/system_components/")
  end

  # ==================================
  # update tests

  test "update - bad request", context do
    component = Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = put conn(), "/system_components/#{component.id}", %{}
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "update - internal server error", context do
    component = Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :update, fn _ -> raise "bad news bears" end)

    conn = put conn(), "/system_components/#{component.id}", %{"messaging_exchange_id" => context[:exchange].id, "type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "upgrade_strategy" => "manaul", "deployment_repo"=> "https://github.com/test/test.git", "deployment_repo_git_ref"=> "123abc"}
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "update - conflict", context do
    component = Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))
    component2 = Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test2", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = put conn(), "/system_components/#{component.id}", %{"messaging_exchange_id" => context[:exchange].id, "type" => "test2", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "upgrade_strategy" => "manaul", "deployment_repo"=> "https://github.com/test/test.git", "deployment_repo_git_ref"=> "123abc"}
    assert conn.status == 409
  end

  test "update - success", context do
    component = Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = put conn(), "/system_components/#{component.id}", %{"messaging_exchange_id" => context[:exchange].id, "type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref"=> "123abc", "upgrade_strategy"=> "hourly", "deployment_repo"=> "https://github.com/test/test.git", "deployment_repo_git_ref"=> "123abc"}
    assert conn.status == 204
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/system_components/")
    case Repo.get(SystemComponent, component.id) do
      nil -> assert true == false
      component2 -> assert component2.upgrade_strategy == "hourly"
    end
  end

  test "destroy - invalid component" do
    conn = delete conn(), "/system_components/0123456789"
    assert conn.status == 404
  end

  test "destroy - valid component", context do
    component = Repo.insert(SystemComponent.new(%{messaging_exchange_id: context[:exchange].id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = delete conn(), "/system_components/#{component.id}"
    assert conn.status == 204

    case Repo.get(SystemComponent, component.id) do
      nil -> assert true == true
      component -> assert component != nil
    end
  end
end