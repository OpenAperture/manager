defmodule OpenapertureManager.Repo.Migrations.AddEnvironmentalVariablesTable do
  use Ecto.Migration

  # Using "text" as the column type for the env var value feels a little
  # weird, but there's not hard limit on env var length, and (on Postgres)
  # perf is the same on text and varchar
  def change do
    create table(:product_environmental_variables) do
      add :product_id, references(:products), null: false
      add :product_environment_id, references(:product_environments)
      add :name, :string, size: 1024, null: false
      add :value, :text
      timestamps
    end

    create index(:product_environmental_variables, [:product_id, :product_environment_id, :name], unique: true)
    create index(:product_environmental_variables, [:product_id, :name])
  end
end