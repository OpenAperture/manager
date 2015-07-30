defmodule OpenAperture.Manager.Controllers.SystemComponentRefTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  alias OpenAperture.Manager.DB.Models.SystemComponentRef
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Plugs.Authentication

  require Repo
  import Ecto.Query  

  setup_all do
    :meck.new(Authentication, [:passthrough])
    :meck.expect(Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn ->
      :meck.unload
      Repo.delete_all(SystemComponentRef)
    end    
    :ok
  end

  setup do
    Repo.delete_all(SystemComponentRef)
    :ok
  end

  @endpoint OpenAperture.Manager.Endpoint

  # ==================================
  # index tests

  test "index - no components" do
    conn = get conn(), "/system_component_refs"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index - components" do
    Repo.insert!(SystemComponentRef.new(%{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))
    Repo.insert!(SystemComponentRef.new(%{type: "test2", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))

    conn = get conn(), "/system_component_refs"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2
  end

  # ==================================
  # show tests

  test "show - invalid component" do
    conn = get conn(), "/system_component_refs/junk"
    assert conn.status == 404
  end

  test "show - valid component" do
    component = Repo.insert!(SystemComponentRef.new(%{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))

    conn = get conn(), "/system_component_refs/#{component.type}"
    assert conn.status == 200

    returned_component = Poison.decode!(conn.resp_body)
    assert returned_component != nil
    assert returned_component["type"] == component.type
    assert returned_component["source_repo"] == component.source_repo
    assert returned_component["source_repo_git_ref"] == component.source_repo_git_ref
    assert returned_component["auto_upgrade_enabled"] == component.auto_upgrade_enabled
  end  

  # ==================================
  # create tests

  test "create - conflict" do
    Repo.insert!(SystemComponentRef.new(%{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))

    conn = post conn(), "/system_component_refs", %{"type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "auto_upgrade_enabled" => true}
    assert conn.status == 409
  end

  test "create - bad request" do
    conn = post conn(), "/system_component_refs", %{}
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert!, fn _ -> raise "bad news bears" end)

    conn = post conn(), "/system_component_refs", %{"type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "auto_upgrade_enabled" => true}
    
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success" do
    conn = post conn(), "/system_component_refs", %{"type" => "test", "source_repo" => "https://github.com/test/test.git", "source_repo_git_ref" => "123abc", "auto_upgrade_enabled" => true}
    
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/system_component_refs/")
  end

  # ==================================
  # update tests

  test "update - bad request" do
    component = Repo.insert!(SystemComponentRef.new(%{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))

    conn = put conn(), "/system_component_refs/#{component.type}", %{}
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "update - internal server error" do
    component = Repo.insert!(SystemComponentRef.new(%{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [component] end)
    :meck.expect(Repo, :update!, fn _ -> raise "bad news bears" end)

    conn = put conn(), "/system_component_refs/#{component.type}", %{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: false}
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "update - success" do
    component = Repo.insert!(SystemComponentRef.new(%{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))

    conn = put conn(), "/system_component_refs/#{component.type}", %{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: false}
    assert conn.status == 204
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/system_component_refs/")
    query = from scr in SystemComponentRef,
      where: scr.type == ^component.type,
      select: scr
    case Repo.all(query) do
      [] -> assert true == false
      raw_components -> assert List.first(raw_components).auto_upgrade_enabled == false
    end
  end

  test "destroy - invalid component" do
    conn = delete conn(), "/system_component_refs/0123456789"
    assert conn.status == 404
  end

  test "destroy - valid component" do
    component = Repo.insert!(SystemComponentRef.new(%{type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", auto_upgrade_enabled: true}))

    conn = delete conn(), "/system_component_refs/#{component.type}"
    assert conn.status == 204

    query = from scr in SystemComponentRef,
      where: scr.type == ^component.type,
      select: scr
    case Repo.all(query) do
      [] -> assert true == true
      raw_components -> assert raw_components != nil
    end
  end
end