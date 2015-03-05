defmodule ProjectOmeletteManager.Repo.Migrations.RenameEnvironmentsNameColumnToNameOnProductEnvironmentsTable do
  use Ecto.Migration

  def up do
    [
      "ALTER TABLE product_environments RENAME COLUMN environment_name TO name",
      "ALTER TABLE product_environments RENAME CONSTRAINT product_environments_product_id_environment_name_key TO product_environments_product_id_name_key"
    ]
  end

  def down do
    [
      "ALTER TABLE product_environments RENAME CONSTRAINT product_environments_product_id_name_key TO product_environments_product_id_environment_name_key",
      "ALTER TABLE product_environments RENAME COLUMN name to environment_name"
    ]
  end
end
