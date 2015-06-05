defmodule OpenAperture.Manager.Repo.Migrations.ChangeRpcResponseBodyType do
  use Ecto.Migration

  def up do
    alter table(:messaging_rpc_requests) do
      remove :request_body
      add :request_body, :text, null: true
      remove :response_body
      add :response_body, :text, null: true
    end
  end

  def down do
    alter table(:messaging_rpc_requests) do
      remove :request_body
      add :request_body, :string, null: true
      remove :response_body
      add :response_body, :string, null: true
    end
  end
end
