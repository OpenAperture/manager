require Timex.Time

defmodule DB.Queries.Workflow.Test do
  use ExUnit.Case, async: false
  use Timex

  alias ProjectOmeletteManager.DB.Models.Workflow

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Queries.Workflow, as: WorkflowQuery

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(Workflow)
    end
  end

  test "get_workflows - last 24 hours exists" do
    Repo.delete_all(Workflow)
    
    workflow_old_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]

    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(25*60*60))
    then = from_erl(lookback_time)

    _workflow_old = %Workflow{id: workflow_old_id, inserted_at: then} |> Repo.insert
    workflow_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]
    _workflow = Workflow.new(%{id: workflow_id}) |> Repo.insert

    results = Repo.all(WorkflowQuery.get_workflows(24))
    assert results != nil
    assert length(results) == 1
    assert List.first(results).id == workflow_id
  end

  test "get_workflows - last 24 hours no entries" do
    workflow_old_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]

    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(25*60*60))
    then = from_erl(lookback_time)

    _workflow_old = %Workflow{id: workflow_old_id, inserted_at: then} |> Repo.insert

    results = Repo.all(WorkflowQuery.get_workflows(24))
    assert results != nil
    assert length(results) == 0
  end

  test "get_workflows - all entries exists" do
    Repo.delete_all(Workflow)
    workflow_old_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]

    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(25*60*60))
    then = from_erl(lookback_time)

    _workflow_old = %Workflow{id: workflow_old_id, inserted_at: then} |> Repo.insert

    workflow_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]
    _workflow = %Workflow{id: workflow_id} |> Repo.insert

    results = Repo.all(WorkflowQuery.get_workflows(0))
    assert results != nil
    assert length(results) == 2
    Enum.reduce results, [], fn result, _errors ->
      cond do
        result.id == workflow_old_id -> assert result.id == workflow_old_id
        result.id == workflow_id -> assert result.id == workflow_id
        true -> assert true == false
      end
    end
  end  

  test "get_workflows_by_deployment_repo - last 24 hours only current deploy repo" do
    workflow_old_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]
    _workflow_old = Workflow.new(%{id: workflow_old_id, deployment_repo: "bad-news-bears", inserted_at: Ecto.DateTime.utc()}) |> Repo.insert

    workflow_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]
    _workflow = Workflow.new(%{id: workflow_id, deployment_repo: "Perceptive-Cloud/myapp", inserted_at: Ecto.DateTime.utc()}) |> Repo.insert

    results = Repo.all(WorkflowQuery.get_workflows_by_deployment_repo("Perceptive-Cloud/myapp", 24))
    assert results != nil
    assert length(results) == 1
    assert List.first(results).id == workflow_id
  end

  test "get_workflows_by_deployment_repo - last 24 hours exists" do
    workflow_old_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]

    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(25*60*60))
    then = from_erl(lookback_time)

    _workflow_old = %Workflow{id: workflow_old_id, deployment_repo: "Perceptive-Cloud/myapp", inserted_at: then} |> Repo.insert

    workflow_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]
    _workflow = Workflow.new(%{id: workflow_id, deployment_repo: "Perceptive-Cloud/myapp"}) |> Repo.insert

    results = Repo.all(WorkflowQuery.get_workflows_by_deployment_repo("Perceptive-Cloud/myapp", 24))
    assert results != nil
    assert length(results) == 1
    assert List.first(results).id == workflow_id
  end

  test "get_workflows_by_deployment_repo - last 24 hours no entries" do
    workflow_old_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]

    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(25*60*60))
    then = from_erl(lookback_time)

    _workflow_old = %Workflow{id: workflow_old_id, deployment_repo: "Perceptive-Cloud/myapp", inserted_at: then} |> Repo.insert

    results = Repo.all(WorkflowQuery.get_workflows_by_deployment_repo("Perceptive-Cloud/myapp", 24))
    assert results != nil
    assert length(results) == 0
  end

  test "get_workflows_by_deployment_repo - all entries exists" do
    workflow_old_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]

    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(25*60*60))
    then = from_erl(lookback_time)

    _workflow_old = %Workflow{id: workflow_old_id, deployment_repo: "Perceptive-Cloud/myapp", inserted_at: then} |> Repo.insert

    workflow_id = ("#{UUID.uuid1()}" |> UUID.info)[:binary]
    _workflow = Workflow.new(%{id: workflow_id, deployment_repo: "Perceptive-Cloud/myapp", inserted_at: Ecto.DateTime.utc()}) |> Repo.insert

    results = Repo.all(WorkflowQuery.get_workflows_by_deployment_repo("Perceptive-Cloud/myapp"))
    assert results != nil
    assert length(results) == 2
    Enum.reduce results, [], fn result, _errors ->
      cond do
        result.id == workflow_old_id -> assert result.id == workflow_old_id
        result.id == workflow_id -> assert result.id == workflow_id
        true -> assert true == false
      end
    end
  end 

  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end

end