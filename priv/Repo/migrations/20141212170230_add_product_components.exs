defmodule ProjectOmeletteManager.Repo.Migrations.AddProductComponents do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_components (
      id                      SERIAL PRIMARY KEY,
      product_id              integer NOT NULL REFERENCES products,
			name                    varchar(1024) NOT NULL,
			type                    varchar(1024) NOT NULL,
      created_at              timestamp,
      updated_at              timestamp
    )
    """,
    "CREATE INDEX pcomp_product_idx ON product_components(product_id)"
  ]
  end

  def down do
    ["DROP INDEX pcomp_product_idx",
     "DROP TABLE product_components"]
  end
end
