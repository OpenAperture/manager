defmodule OpenAperture.Manager.Controllers.WorkflowsTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest
  use Timex

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Controllers.Workflows
  alias OpenAperture.Manager.DB.Models.Workflow, as: WorkflowDB

  alias OpenAperture.WorkflowOrchestratorApi.WorkflowOrchestrator.Publisher, as: OrchestratorPublisher

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn ->
      Repo.delete_all(WorkflowDB)
      :meck.unload
    end    
    :ok
  end

  @endpoint OpenAperture.Manager.Endpoint

  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end  

  test "get workflow" do
    workflow_uuid = Ecto.UUID.generate()
    _workflow = Repo.insert!(%WorkflowDB{
      id: workflow_uuid, 
      milestones: Poison.encode!([:build, :deploy]),
      workflow_step_durations: Poison.encode!(%{build: "24 seconds"}),
      event_log: Poison.encode!(["Event 1", "Event 2"]),
      inserted_at: from_erl(:calendar.universal_time)}
    )

    conn = get conn(), "/workflows/#{workflow_uuid}"
    assert conn.status == 200
    assert Poison.decode!(conn.resp_body)["id"] == "#{workflow_uuid}"
  end

  test "get non-existent" do
    conn = get conn(), "/workflows/#{Ecto.UUID.generate()}"
    assert conn.status == 404
    assert conn.resp_body == ""
  end

  test "get by repo success all builds" do
    workflow_uuid = Ecto.UUID.generate()

    deployment_repo_name = "Test-Org/#{Ecto.UUID.generate()}_docker"
    _workflow = Repo.insert!(%WorkflowDB{id: workflow_uuid, deployment_repo: deployment_repo_name, inserted_at: from_erl(:calendar.universal_time)})

    conn = get conn(), "/workflows?deployment_repo=#{deployment_repo_name}&lookback=0"
    assert conn.status == 200
    assert conn.resp_body != nil
    result = Poison.decode!(conn.resp_body)
    assert result != nil
    assert length(result) == 1
    assert List.first(result)["id"] == "#{workflow_uuid}"
  end

  test "get by repo success in last 24 hours" do
    workflow_uuid = Ecto.UUID.generate()

    deployment_repo_name = "Test-Org/#{Ecto.UUID.generate()}_docker"
    _workflow = Repo.insert!(%WorkflowDB{id: workflow_uuid, deployment_repo: deployment_repo_name, inserted_at: from_erl(:calendar.universal_time)})

    conn = get conn(), "/workflows?deployment_repo=#{deployment_repo_name}"
    assert conn.status == 200
    assert conn.resp_body != nil
    result = Poison.decode!(conn.resp_body)
    assert result != nil
    assert length(result) == 1
    assert List.first(result)["id"] == "#{workflow_uuid}"
  end

  test "get by source repo success in last 24 hours" do
    workflow_uuid = Ecto.UUID.generate()

    #this is actually the deployment repo under the covers
    source_repo_name = "#{Ecto.UUID.generate()}"
    source_repo = "Test-Org/#{source_repo_name}_docker"
    _workflow = Repo.insert!(%WorkflowDB{id: workflow_uuid, deployment_repo: source_repo, inserted_at: from_erl(:calendar.universal_time)})

    conn = get conn(), "/workflows?source_repo=Test-Org/#{source_repo_name}"
    assert conn.status == 200
    assert conn.resp_body != nil
    result = Poison.decode!(conn.resp_body)
    assert result != nil
    assert length(result) == 1
    assert List.first(result)["id"] == "#{workflow_uuid}"
  end

  test "get by source repo success all builds" do
    workflow_uuid = Ecto.UUID.generate() 

    #this is actually the deployment repo under the covers
    source_repo_name = "#{Ecto.UUID.generate()}"
    source_repo = "Test-Org/#{source_repo_name}_docker"
    _workflow = Repo.insert!(%WorkflowDB{id: workflow_uuid, deployment_repo: source_repo, inserted_at: from_erl(:calendar.universal_time)})

    conn = get conn(), "/workflows?source_repo=Test-Org/#{source_repo_name}&lookback=0"
    assert conn.status == 200
    assert conn.resp_body != nil
    result = Poison.decode!(conn.resp_body)
    assert result != nil
    assert length(result) == 1
    assert List.first(result)["id"] ==  "#{workflow_uuid}"
  end

  test "get by repo no params" do
    conn = get conn(), "/workflows"
    assert conn.status == 200
    assert conn.resp_body != nil
  end

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert!, fn _ -> raise "bad news bears" end)

    conn = post conn(), "/workflows", %{"deployment_repo" => "#{Ecto.UUID.generate()}"}
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success" do
    now = Date.from(:calendar.universal_time, :utc)

    name = Ecto.UUID.generate()
    conn = post conn(), "/workflows", %{"deployment_repo" => name, "scheduled_start_time" => DateFormat.format!(now, "{RFC1123}")}
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/workflows/")
  end  

  test "update - internal server error" do
    workflow_id = Ecto.UUID.generate()  
    _workflow = Repo.insert!(WorkflowDB.new(%{id: workflow_id}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :update!, fn _ -> raise "bad news bears" end)

    conn = put conn(), "/workflows/#{workflow_id}", %{"name" => "#{Ecto.UUID.generate()}"}
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "update - success" do
    workflow_id = Ecto.UUID.generate()  
    _workflow = Repo.insert!(WorkflowDB.new(%{id: workflow_id}))

    deployment_repo = "#{Ecto.UUID.generate()}"
    conn = put conn(), "/workflows/#{workflow_id}", %{
      "deployment_repo" => deployment_repo,
      "milestones" => [:build, :deploy],
      "workflow_step_durations" => %{"build" => "12 seconds"},
      "event_log" => ["Event 1", "Event 2"]
    }

    assert conn.status == 204
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/workflows/")
    updated_workflow = Repo.get(WorkflowDB, workflow_id)
    assert updated_workflow.deployment_repo == deployment_repo
  end  

  test "destroy - invalid workflow" do
    conn = delete conn(), "/workflows/1234567890"
    assert conn.status == 404
  end

  test "destroy - valid workflow" do
    workflow_id = Ecto.UUID.generate()  
    _workflow = Repo.insert!(WorkflowDB.new(%{id: workflow_id}))

    conn = delete conn(), "/workflows/#{workflow_id}"
    assert conn.status == 204

    assert Repo.get(WorkflowDB, workflow_id) == nil
  end  

  # ==========================================
  # execute tests

  test "execute - invalid workflow" do
    conn = post conn(), "/workflows/1234567890/execute"
    assert conn.status == 404
  end

  test "execute - completed workflow" do
    workflow_id = Ecto.UUID.generate()    
    _workflow = Repo.insert!(WorkflowDB.new(%{id: workflow_id, workflow_completed: true}))

    conn = post conn(), "/workflows/#{workflow_id}/execute"
    assert conn.status == 409
  end

  test "execute - completed in-progress" do
    workflow_id = Ecto.UUID.generate()  
    _workflow = Repo.insert!(WorkflowDB.new(%{id: workflow_id, current_step: "something"}))

    conn = post conn(), "/workflows/#{workflow_id}/execute"
    assert conn.status == 409
  end

  test "execute - publish fails" do
    :meck.new(OrchestratorPublisher, [:passthrough])
    :meck.expect(OrchestratorPublisher, :execute_orchestration, fn _ -> {:error, "bad news bears"} end)

    workflow_id = Ecto.UUID.generate()   
    _workflow = Repo.insert!(WorkflowDB.new(%{id: workflow_id}))

    conn = post conn(), "/workflows/#{workflow_id}/execute"
    assert conn.status == 500
  after
    :meck.unload(OrchestratorPublisher)
  end  

  test "execute - success" do
    :meck.new(OrchestratorPublisher, [:passthrough])
    :meck.expect(OrchestratorPublisher, :execute_orchestration, fn _ -> :ok end)

    workflow_id = Ecto.UUID.generate()   
    _workflow = Repo.insert!(WorkflowDB.new(%{id: workflow_id}))

    conn = post conn(), "/workflows/#{workflow_id}/execute"
    assert conn.status == 202
  after
    :meck.unload(OrchestratorPublisher)    
  end

  test "process_milestones - success" do
    assert Workflows.process_milestones(["deploy"]) == Poison.encode! ["config", "deploy"]
    assert Workflows.process_milestones(["build"]) == Poison.encode! ["build"]
    assert Workflows.process_milestones(["config", "deploy"]) == Poison.encode! ["config", "deploy"]
    assert Workflows.process_milestones(["build", "deploy"]) == Poison.encode! ["build", "deploy"]
  end
end