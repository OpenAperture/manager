defmodule OpenapertureManager.Repo.Migrations.AddProductComponents do
  use Ecto.Migration

  def change do
    create table(:product_components) do
      add :product_id, references(:products), null: false
      add :name, :string, null: false, size: 1024
      add :type, :string, null: false, size: 1024
      timestamps
    end
    create index(:product_components, [:product_id])
  end
end
