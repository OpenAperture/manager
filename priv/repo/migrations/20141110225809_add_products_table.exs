defmodule ProjectOmeletteManager.Repo.Migrations.AddProductsTable do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string, null: false
      timestamps
    end
    create index(:products, [:name], unique: true)
  end
end