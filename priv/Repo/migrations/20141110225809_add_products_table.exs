defmodule ProjectOmeletteManager.Repo.Migrations.AddProductsTable do
  use Ecto.Migration

  def up do
    """
    CREATE TABLE products (
      id           SERIAL,
      name         varchar(128) UNIQUE NOT NULL,
      created_at   timestamp,
      updated_at   timestamp)
    """
  end

  def down do
    "DROP TABLE products"
  end
end
