defmodule OpenAperture.Manager.DB.Models.SystemComponentRef do
  @required_fields [:type, :source_repo, :source_repo_git_ref, :auto_upgrade_enabled]
  @optional_fields []

  use OpenAperture.Manager.DB.Models.BaseModel

  schema "system_component_refs" do
    field :type
    field :source_repo
    field :source_repo_git_ref
    field :auto_upgrade_enabled, :boolean
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
    |> validate_length(:type, min: 1)
    |> validate_length(:source_repo, min: 1)
    |> validate_length(:source_repo_git_ref, min: 1)
  end

  def destroy(model) do
    Repo.delete model
  end
end