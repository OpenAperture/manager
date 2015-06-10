defmodule OpenAperture.Manager.DB.Models.MessagingRpcRequest do
  @required_fields [:status]
  @optional_fields [:request_body, :response_body]
  use OpenAperture.Manager.DB.Models.BaseModel

  schema "messaging_rpc_requests" do
    field :request_body
    field :response_body
    field :status
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

  def destroy(model) do
    Repo.delete model
  end
end