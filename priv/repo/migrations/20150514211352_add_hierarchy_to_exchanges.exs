defmodule OpenAperture.Manager.Repo.Migrations.AddHierarchyToExchanges do
  use Ecto.Migration

  def change do
		alter table(:messaging_exchanges) do
		  add :parent_exchange_id, references(:messaging_exchanges)
		  add :routing_key_fragment, :string
		end

		create index(:messaging_exchanges, [:parent_exchange_id], unique: false)
  end
end
