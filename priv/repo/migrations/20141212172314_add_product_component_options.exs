defmodule ProjectOmeletteManager.Repo.Migrations.AddProductComponentOptions do
  use Ecto.Migration

  def change do
    create table(:product_component_options) do
      add :product_component_id, references(:product_components), null: false
      add :name, :string, null: false, size: 1024
      add :value, :text
      add :type, :text
      timestamps
    end
    create index(:product_component_options, [:product_component_id])
  end
end
