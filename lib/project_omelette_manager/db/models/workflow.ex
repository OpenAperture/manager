#
# == workflow.ex
#
# This module contains the db schema the 'workflows' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2015 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
require Timex.Time

defmodule ProjectOmeletteManager.DB.Models.Workflow do
  @required_fields [:id]
  @optional_fields [:deployment_repo,:deployment_repo_git_ref,:source_repo,:source_repo_git_ref,:source_commit_hash,
                    :milestones,:current_step,:elapsed_step_time,:elapsed_workflow_time,:workflow_duration,
                    :workflow_step_durations,:workflow_error,:workflow_completed,:event_log]
  use ProjectOmeletteManager.DB.Models.BaseModel
  use Timex

  @primary_key {:id, :uuid, []}
  
  schema "workflows" do
    field :deployment_repo,           :string
    field :deployment_repo_git_ref,   :string
    field :source_repo,               :string
    field :source_repo_git_ref,       :string
    field :source_commit_hash,        :string
    field :milestones,                :string
    field :current_step,              :string
    field :elapsed_step_time,         :string
    field :elapsed_workflow_time,     :string
    field :workflow_duration,         :string
    field :workflow_step_durations,   :string
    field :workflow_error,            :boolean
    field :workflow_completed,        :boolean
    field :event_log,                 :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
  
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
    :updated_at
  ]

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
          uuid = uuid_to_string(raw_workflow.id)

          workflow = to_sendable(raw_workflow, @workflow_sendable_fields)
          if (workflow != nil) do
            if (workflow[:id] != nil) do
              workflow = Map.put(workflow, :id, uuid)
            end

            if (workflow[:inserted_at] != nil) do
              workflow = Map.put(workflow, :inserted_at, "#{:httpd_util.rfc1123_date(Ecto.DateTime.to_erl(workflow[:inserted_at]))}")
            end

            if (workflow[:updated_at] != nil) do
              workflow = Map.put(workflow, :updated_at, "#{:httpd_util.rfc1123_date(Ecto.DateTime.to_erl(workflow[:updated_at]))}")
            end
        
            workflows = workflows ++ [workflow]
          end

          workflows
        end
    end
  end
  
  @doc false
  #to_sendable prepars a struct (or plain old map) for transmission
  #over-the-wire by converting structs into regular maps and
  #stripping out any fields not provided in the "allowed_fields" whitelist. If
  #no "allowed_fields" parameter is specified, all fields will be included.
  #
  ## Example
  #
  #  > coolstruct = %CoolStruct{name: "Jordan", coolness: "very cool", rank: 17}
  #  %CoolStruct{name: "Jordan", coolness: "very cool", rank: 17}
  #  > to_sendable(coolstruct, [:name, :rank])
  #  %{name: "Jordan", rank: 17}
  #
  @spec to_sendable(Map.t, List.t) :: Map.t
  defp to_sendable(item, allowed_fields)

  defp to_sendable(item, nil) when is_map(item) do
    to_sendable(item, Map.keys(item))
  end

  defp to_sendable(item, allowed_fields) when is_map(item) do
    item
    |> Map.from_struct()
    |> Map.take(allowed_fields)
  end

  #https://github.com/zyro/elixir-uuid/blob/master/lib/uuid.ex#L246
  defp uuid_to_string(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b",
                   [u0, u1, u2, u3, u4])
      |> to_string
  end
end
