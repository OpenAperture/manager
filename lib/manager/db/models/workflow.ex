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

defmodule OpenAperture.Manager.DB.Models.Workflow do
  @required_fields [:id]
  @optional_fields [:deployment_repo,:deployment_repo_git_ref,:source_repo,:source_repo_git_ref,:source_commit_hash,
                    :milestones,:current_step,:elapsed_step_time,:elapsed_workflow_time,:workflow_duration,
                    :workflow_step_durations,:workflow_error,:workflow_completed,:event_log]
  use OpenAperture.Manager.DB.Models.BaseModel
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
end
