defmodule OpenAperture.Manager.DB.Models.MessagingExchangeModule do
  @required_fields [:messaging_exchange_id, :hostname, :type, :status, :workload]
  @optional_fields [:source_repo, :source_repo_git_ref, :deployment_repo, :deployment_repo_git_ref]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.MessagingExchange

  schema "messaging_exchange_modules" do
    belongs_to :messaging_exchange,   MessagingExchange
    field :hostname
    field :type
    field :status
    field :workload
    field :source_repo
    field :source_repo_git_ref
    field :deployment_repo
    field :deployment_repo_git_ref
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

  def destroy(model) do
    Repo.delete! model
  end
end