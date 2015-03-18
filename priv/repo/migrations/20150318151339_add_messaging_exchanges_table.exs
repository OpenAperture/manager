defmodule :"Elixir.ProjectOmeletteManager.Repo.Migrations.AddMessagingExchangesTable.ex" do
  use Ecto.Migration

  def change do
    create table(:messaging_exchanges) do
      add :name, :string, null: false, size: 1024
      timestamps
    end
  end
end
