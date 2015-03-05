defmodule ProjectOmeletteManager.Repo.Migrations.AddEnvironmentalVariablesTable do
  use Ecto.Migration

  # Using "text" as the column type for the env var value feels a little
  # weird, but there's not hard limit on env var length, and (on Postgres)
  # perf is the same on text and varchar
  def up do
    ["""
    CREATE TABLE product_environmental_variables (
      id                      SERIAL PRIMARY KEY,
      product_id              integer NOT NULL REFERENCES products,
      product_environment_id  integer REFERENCES product_environments,
      name                    varchar(1024) NOT NULL,
      value                   text,
      created_at              timestamp,
      updated_at              timestamp,
      CONSTRAINT pev_prod_id_prod_env_id_name_key UNIQUE(product_id, product_environment_id, name))
    """,
    "CREATE INDEX pev_prod_id_name_idx ON product_environmental_variables(product_id, name)",
    "CREATE INDEX pev_prod_id_prod_env_id_name_idx ON product_environmental_variables(product_id, name)",
    "CREATE UNIQUE INDEX pev_prod_id_name_prod_env_null_idx ON product_environmental_variables(product_id, name) WHERE product_environment_id IS NULL"]
  end

  def down do
    ["DROP INDEX pev_prod_id_prod_env_id_name_idx",
     "DROP INDEX pev_prod_id_name_idx",
     "DROP TABLE product_environmental_variables"]
  end
end
