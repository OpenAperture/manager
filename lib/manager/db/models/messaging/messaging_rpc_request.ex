defmodule OpenAperture.Manager.DB.Models.MessagingRpcRequest do
  use Ecto.Model

  schema "messaging_rpc_requests" do
    field :request_body
    field :response_body
    field :status
    timestamps
  end

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(status), ~w(request_body response_body))
  end

  def destroy(model) do
    Repo.delete model
  end
end