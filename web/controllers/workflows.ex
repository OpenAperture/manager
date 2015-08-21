#
# == workflow_controller.ex
#
# This module contains the controller for managing Workflows
#
require Logger

defmodule OpenAperture.Manager.Controllers.Workflows do
  use OpenAperture.Manager.Web, :controller
  use Timex

  require Repo

  alias OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.DB.Models.Workflow, as: WorkflowDB
  alias OpenAperture.Manager.DB.Queries.Workflow, as: WorkflowQuery
  alias OpenAperture.Manager.Configuration

  alias OpenAperture.WorkflowOrchestratorApi.Request, as: OrchestratorRequest
  alias OpenAperture.WorkflowOrchestratorApi.WorkflowOrchestrator.Publisher, as: OrchestratorPublisher

  plug :action

  @moduledoc """
  This module contains the controller for managing Workflows
  """  

  @workflow_sendable_fields [
    :id, 
    :deployment_repo, 
    :deployment_repo_git_ref, 
    :source_repo,
    :source_repo_git_ref,
    :source_commit_hash, 
    :milestones,         
    :current_step,       
    :elapsed_step_time,  
    :elapsed_workflow_time,
    :workflow_duration,    
    :workflow_step_durations,
    :workflow_error,         
    :workflow_completed,     
    :event_log,
    :inserted_at, 
    :updated_at,
    :scheduled_start_time,
    :execute_options
  ]

  @doc """
  GET /workflows - Retrieve all Workflows for a lookback period
    * Query Parameters:  
      * lookback - integer, defaults to 24 (specify 0 for all)
      * deployment_repo - string containing the deployment repo
      * source_repo - string containing the source repo

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(term, [any]) :: term
  def index(conn, params) do
    lookback = if params["lookback"] != nil do
      {int, _} = Integer.parse(params["lookback"])
      int
    else
      24
    end

    deployment_repo = cond do
      params["deployment_repo"] != nil -> params["deployment_repo"]
      params["source_repo"] != nil     -> "#{params["source_repo"]}_docker"
      true -> nil
    end

    raw_workflows = cond do
    deployment_repo != nil && String.length(deployment_repo) > 0 ->
      Repo.all(WorkflowQuery.get_workflows_by_deployment_repo(deployment_repo, lookback))
    true ->
      Repo.all(WorkflowQuery.get_workflows(lookback))
    end

    json conn, convert_raw_workflows(raw_workflows)
 end

  @doc """
  GET /workflowss/:id

  Retrieve a specific Workflow

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection.
  """
  @spec show(term, Map) :: term
  def show(conn, %{"id" => id} = _params) do
    case get_workflow(id) do
      nil -> resp(conn, :not_found, "")
      raw_workflow -> json conn, List.first(convert_raw_workflows([raw_workflow]))      
    end
  end

  defp has_milestone?(milestones, milestone) do
    length(Enum.filter(milestones, &(&1 == milestone))) > 0
  end

  def process_milestones(milestones) do
    if milestones != nil do
      if !has_milestone?(milestones, "build") && !has_milestone?(milestones, "config") do
        [:config | milestones]
      else
        milestones
      end
      |> Poison.encode!
    else 
      nil
    end
  end

  @doc """
  POST /workflows - Create a Workflow

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(term, [any]) :: term
  def create(conn, params) do
    id = Ecto.UUID.generate()

    milestones = process_milestones(params["milestones"])

    workflow_step_durations = if params["workflow_step_durations"] != nil do
      Poison.encode!(params["workflow_step_durations"])
    else
      nil
    end

    event_log = if params["event_log"] != nil do
      Poison.encode!(params["event_log"])
    else
      nil
    end

    workflow_completed = if params["workflow_completed"] != nil do
      params["workflow_completed"]
    else
      false
    end

    scheduled_start_time = if params["scheduled_start_time"] != nil do
      datetime = DateFormat.parse!(params["scheduled_start_time"], "{RFC1123}")
      erl_date = DateConvert.to_erlang_datetime(datetime)
      Ecto.DateTime.from_erl(erl_date)
    else
      nil
    end

    execute_options = if params["execute_options"] != nil do
      Poison.encode!(params["execute_options"])
    else
      nil
    end    

    changeset = WorkflowDB.new(%{
      :id => id,
      :deployment_repo => trim_trailing(params["deployment_repo"]),
      :deployment_repo_git_ref => params["deployment_repo_git_ref"],
      :source_repo => trim_trailing(params["source_repo"]),
      :source_repo_git_ref => params["source_repo_git_ref"],
      :source_commit_hash => params["source_commit_hash"],
      :milestones => milestones,
      :current_step => params["current_step"],
      :elapsed_step_time => params["elapsed_step_time"],
      :elapsed_workflow_time => params["elapsed_workflow_time"],
      :workflow_duration => params["workflow_duration"],
      :workflow_step_durations => workflow_step_durations,
      :workflow_error => params["workflow_error"],
      :workflow_completed => workflow_completed,
      :event_log => event_log,
      :scheduled_start_time => scheduled_start_time,
      :execute_options => execute_options
    })
    if changeset.valid? do
      try do
        _raw_workflow = Repo.insert!(changeset)
        path = OpenAperture.Manager.Router.Helpers.workflows_path(Endpoint, :show, "#{id}")

        # Set location header
        conn
        |> put_resp_header("location", path)
        |> resp(:created, "")
      rescue
        e ->
          Logger.error("Error inserting Workflow record: #{inspect e}")
          resp(conn, :internal_server_error, "")
      end
    else
      conn
      |> put_status(:bad_request)
      |> json FormatHelper.keywords_to_map(changeset.errors)
    end
  end

  defp trim_trailing(param) when is_bitstring(param) do
    param
    |> String.strip
    |> String.rstrip(?/)
    |> String.rstrip(?\\)
  end

  defp trim_trailing(param), do: param



  @doc """
  PUT/PATCH /workflows/:id - Update a Workflow

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec update(term, [any]) :: term
  def update(conn, %{"id" => id} = params) do
    raw_workflow_id = case Ecto.UUID.cast(id) do
      {:ok, id} -> id
      {:error, _} -> nil
      _ -> nil
    end
    raw_workflow = get_workflow(raw_workflow_id)
    if raw_workflow == nil do
      resp(conn, :not_found, "")
    else
      workflow_params = Map.put(params, "id", raw_workflow_id)

      if params["milestones"] != nil do
        workflow_params = Map.put(workflow_params, "milestones", Poison.encode!(params["milestones"]))
      end

      if params["workflow_step_durations"] != nil do
        workflow_params = Map.put(workflow_params, "workflow_step_durations", Poison.encode!(params["workflow_step_durations"]))
      end

      if params["event_log"] != nil do
        workflow_params = Map.put(workflow_params, "event_log", Poison.encode!(params["event_log"]))
      end

      if params["workflow_completed"] == nil do
        workflow_params = Map.put(workflow_params, "workflow_completed", false)
      end

      if params["execute_options"] != nil do
        workflow_params = Map.put(workflow_params, "execute_options", Poison.encode!(params["execute_options"]))
      end

      if params["scheduled_start_time"] != nil do
        datetime = DateFormat.parse!(params["scheduled_start_time"], "{RFC1123}")
        erl_date = DateConvert.to_erlang_datetime(datetime)
        workflow_params = Map.put(workflow_params, "scheduled_start_time", Ecto.DateTime.from_erl(erl_date))
      end

      changeset = WorkflowDB.update(raw_workflow, workflow_params)
      if changeset.valid? do
        try do
          Repo.update!(changeset)
          path = OpenAperture.Manager.Router.Helpers.workflows_path(Endpoint, :show, id)
          conn
          |> put_resp_header("location", path)
          |> resp(:no_content, "")
        rescue
          e ->
            Logger.error("Error updating Workflow record: #{inspect e}")
            resp(conn, :internal_server_error, "")
        end
      else
        conn
        |> put_status(:bad_request)
        |> json FormatHelper.keywords_to_map(changeset.errors)
      end
    end
  end

  @doc """
  DELETE /workflows/:id - Delete a Workflow

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy(term, [any]) :: term
  def destroy(conn, %{"id" => id} = _params) do
    raw_workflow_id = case Ecto.UUID.cast(id) do
      {:ok, id} -> id
      {:error, _} -> nil
      _ -> nil
    end
    case get_workflow(raw_workflow_id) do
      nil -> resp(conn, :not_found, "")
      workflow ->
        Repo.transaction(fn ->
          WorkflowDB.destroy(workflow)
        end)
        resp(conn, :no_content, "")
    end
  end  

  @doc """
  POST /workflows/:id/execute - Begins execution of a Workflow

  ## Options

  The `conn` option defines the underlying HTTP connection.

  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec execute(term, [any]) :: term
  def execute(conn, %{"id" => id} = params) do
    raw_workflow_id = case Ecto.UUID.cast(id) do
      {:ok, id} -> id
      {:error, _} -> nil
      _ -> nil
    end
    raw_workflow = get_workflow(raw_workflow_id)

    cond do
      raw_workflow == nil -> resp(conn, :not_found, "")
      raw_workflow.workflow_completed == true -> resp(conn, :conflict, "Workflow has already completed")
      raw_workflow.current_step != nil -> resp(conn, :conflict, "Workflow has already been started")
      true ->
        Logger.debug("Preparing to execute Workflow #{raw_workflow.id}...")
        payload = List.first(convert_raw_workflows([raw_workflow]))
        if raw_workflow.execute_options == nil do
          Logger.debug("Workflow #{raw_workflow.id} does not have existing execute_options")

          execute_options = %{}

          if params["force_build"] != nil do
            payload = Map.put(payload, :force_build, params["force_build"])
          end
          execute_options = Map.put(execute_options, "force_build", payload[:force_build])

          build_messaging_exchange_id = to_string(params["build_messaging_exchange_id"])
          if String.length(build_messaging_exchange_id) > 0 do
            payload = case Integer.parse(build_messaging_exchange_id) do
              {messaging_exchange_id, _} -> Map.put(payload, :build_messaging_exchange_id, messaging_exchange_id)
              :error -> payload
            end
          end
          execute_options = Map.put(execute_options, "build_messaging_exchange_id", payload[:build_messaging_exchange_id])

          deploy_messaging_exchange_id = to_string(params["deploy_messaging_exchange_id"])
          if String.length(deploy_messaging_exchange_id) > 0 do
            payload = case Integer.parse(deploy_messaging_exchange_id) do
              {messaging_exchange_id, _} -> Map.put(payload, :deploy_messaging_exchange_id, messaging_exchange_id)
              :error -> payload
            end
          end 
          execute_options = Map.put(execute_options, "deploy_messaging_exchange_id", payload[:deploy_messaging_exchange_id])       
          Logger.debug("Workflow #{raw_workflow.id} execute_options:  #{inspect execute_options}")

          payload = Map.put(payload, :execute_options, execute_options)
          changeset = WorkflowDB.update(raw_workflow, %{execute_options: execute_options})
          if changeset.valid? do
            Repo.update!(changeset)
          end
        else
          Logger.debug("Workflow #{raw_workflow.id} has existing execute_options")
          execute_options = Poison.decode!(raw_workflow.execute_options)
          payload = Map.put(payload, :force_build, execute_options["force_build"])
          payload = Map.put(payload, :build_messaging_exchange_id, execute_options["build_messaging_exchange_id"])
          payload = Map.put(payload, :deploy_messaging_exchange_id, execute_options["deploy_messaging_exchange_id"])
        end

        Logger.debug("Generating WorkflowOrchestrator request for Workflow #{raw_workflow.id}...")
        request = OrchestratorRequest.from_payload(payload)
        request = %{request | notifications_exchange_id: Configuration.get_current_exchange_id}
        request = %{request | notifications_broker_id: Configuration.get_current_broker_id}
        request = %{request | workflow_orchestration_exchange_id: Configuration.get_current_exchange_id}
        request = %{request | workflow_orchestration_broker_id: Configuration.get_current_broker_id}
        request = %{request | orchestration_queue_name: "workflow_orchestration"}

        Logger.debug("WorkflowOrchestrator Request:  #{inspect request}")
        case OrchestratorPublisher.execute_orchestration(request) do
          :ok -> 
            Logger.debug("Successfully sent WorkflowOrchestrator request for Workflow #{raw_workflow.id}!")

            path = OpenAperture.Manager.Router.Helpers.workflows_path(Endpoint, :show, id)

            # Set location header
            conn
            |> put_resp_header("location", path)
            |> resp(:accepted, "")
          {:error, reason} -> 
            Logger.error("Error executing Workflow #{id}: #{inspect reason}")
            resp(conn, :internal_server_error, "")            
        end
    end
  end

  @doc false
  # Method to convert an array of DB.Models.Workflows into an array of List of workflows
  #
  # Options
  #
  # The `raw_workflows` option defines the array of structs of the DB.Models.Workflows to be parsed
  #
  ## Return Values
  #
  # List of parsed product plans
  #
  def convert_raw_workflows(raw_workflows) do
    case raw_workflows do
      nil -> []
      [] -> []
      _ ->
        Enum.reduce raw_workflows, [], fn(raw_workflow, workflows) -> 
          uuid = raw_workflow.id

          workflow = FormatHelper.to_sendable(raw_workflow, @workflow_sendable_fields)
          if (workflow != nil) do
            if (workflow[:id] != nil) do
              workflow = Map.put(workflow, :id, uuid)
            end

            #stored as String in the db
            if (workflow[:milestones] != nil) do
              workflow = Map.put(workflow, :milestones, Poison.decode!(workflow[:milestones]))
            end
            
            #stored as String in the db
            if (workflow[:workflow_step_durations] != nil) do
              workflow = Map.put(workflow, :workflow_step_durations, Poison.decode!(workflow[:workflow_step_durations]))
            end
            
            #stored as String in the db
            if (workflow[:event_log] != nil) do
              workflow = Map.put(workflow, :event_log, Poison.decode!(workflow[:event_log]))
            end        

            #stored as String in the db
            if (workflow[:execute_options] != nil) do
              workflow = Map.put(workflow, :execute_options, Poison.decode!(workflow[:execute_options]))
            end

            if workflow[:scheduled_start_time] != nil do
              {:ok, erl_date} = Ecto.DateTime.dump(workflow[:scheduled_start_time])
              date = Date.from(erl_date, :utc)
              workflow = Map.put(workflow, :scheduled_start_time, DateFormat.format!(date, "{RFC1123}"))
            end           
        
            workflows = workflows ++ [workflow]
          end

          workflows
        end
    end
  end

  @doc false
  # Method to get a Workflow based on a String UUID
  #
  ## Options
  # The option represents a String UUID
  #
  ## Return Value
  #
  # Workflow
  #
  @spec get_workflow(String.t()) :: term
  defp get_workflow(id) do
    cond do 
      id == nil || String.length("#{id}") == 0 -> nil
      true ->
        case id do
          nil -> nil
          raw_id -> Repo.get(WorkflowDB, raw_id)
        end
    end
  end
end
