defmodule OpenAperture.Manager.DB.Models.SystemComponent do
  @required_fields [:type, :messaging_exchange_id, :deployment_repo, :deployment_repo_git_ref, :upgrade_strategy]
  @optional_fields [:source_repo, :source_repo_git_ref, :status, :upgrade_status]

  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.MessagingExchange

  schema "system_components" do
    belongs_to :messaging_exchange, MessagingExchange
    field :type
    field :source_repo
    field :source_repo_git_ref
    field :deployment_repo
    field :deployment_repo_git_ref    
    field :upgrade_strategy
    field :status
    field :upgrade_status
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    changeset = cast(model_or_changeset,  params, @required_fields, @optional_fields)

    messaging_exchange_id = cond do
      params["messaging_exchange_id"] != nil -> params["messaging_exchange_id"]
      params[:messaging_exchange_id] != nil -> params[:messaging_exchange_id]
      true -> nil
    end

    changeset = cond do
      messaging_exchange_id == nil -> add_error(changeset, :messaging_exchange_id, "Missing MessagingExchange")
      Repo.get(MessagingExchange, messaging_exchange_id) == nil -> add_error(changeset, :messaging_exchange_id, "Invalid MessagingExchange")
      true -> changeset
    end

    changeset
    |> validate_length(:type, min: 1)
    |> validate_length(:deployment_repo, min: 1)
    |> validate_length(:deployment_repo_git_ref, min: 1)    
  end

  def destroy(model) do
    Repo.delete! model
  end
end