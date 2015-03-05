defmodule ProjectOmeletteManager.Repo.Migrations.AddProductComponentOptions do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_component_options (
      id                      SERIAL PRIMARY KEY,
      product_component_id    integer NOT NULL REFERENCES product_components,
      name                    varchar(1024) NOT NULL,
      value                   text,
      created_at              timestamp,
      updated_at              timestamp
    )
    """,
    "CREATE INDEX pcomp_opts_comp_idx ON product_component_options(product_component_id)"
  ]
  end

  def down do
    ["DROP INDEX pcomp_opts_comp_idx",
     "DROP TABLE product_component_options"]
  end
end
