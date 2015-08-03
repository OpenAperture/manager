defmodule OpenAperture.Manager.Repo.Migrations.AddMessagingRpcRequestsTable do
  use Ecto.Migration

  def change do
    create table(:messaging_rpc_requests) do
    	add :status, :string, null: false
      add :request_body, :string, null: true
      add :response_body, :string, null: true
      timestamps
    end
  end
end
