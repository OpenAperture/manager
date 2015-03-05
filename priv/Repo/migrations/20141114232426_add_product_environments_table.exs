defmodule ProjectOmeletteManager.Repo.Migrations.AddProductEnvironmentsTable do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_environments (
      id                 SERIAL PRIMARY KEY,
      product_id         integer NOT NULL REFERENCES products,
      environment_name   varchar(128) NOT NULL,
      created_at         timestamp,
      updated_at         timestamp,
      CONSTRAINT product_environments_product_id_environment_name_key UNIQUE(product_id, environment_name))
    """,
    "CREATE INDEX product_environments_product_id_idx ON product_environments(product_id)"]
  end

  def down do
    ["DROP INDEX product_environments_product_id_idx",
     "DROP TABLE product_environments"]
  end
end
