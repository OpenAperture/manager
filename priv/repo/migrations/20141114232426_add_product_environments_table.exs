defmodule OpenapertureManager.Repo.Migrations.AddProductEnvironmentsTable do
  use Ecto.Migration

  def change do
    create table(:product_environments) do
      add :product_id, references(:products), null: false
      add :name, :string, size: 128, null: false
      timestamps
    end
    create index(:product_environments, [:product_id, :name], unique: true)
    create index(:product_environments, [:product_id])
  end
end