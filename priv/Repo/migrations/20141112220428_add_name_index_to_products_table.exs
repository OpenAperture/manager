defmodule ProjectOmeletteManager.Repo.Migrations.AddNameIndexToProductsTable do
  use Ecto.Migration

  def up do
    "CREATE UNIQUE INDEX products_name_idx ON products (name)"
  end

  def down do
    "DROP INDEX products_name_idx"
  end
end
