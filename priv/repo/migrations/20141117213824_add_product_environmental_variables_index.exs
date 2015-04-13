defmodule OpenapertureManager.Repo.Migrations.AddEnvironmentalVariablesIndex do
  use Ecto.Migration

  #Where clause isn't supported in ddl, therefore need to manually create the index with execute,
  #which requires up/down instead of change
  def up do
    execute "CREATE UNIQUE INDEX pev_prod_id_name_prod_env_null_idx ON product_environmental_variables(product_id, name) WHERE product_environment_id IS NULL"
  end
  
  def drop do
    execute "DROP INDEX pev_prod_id_name_prod_env_null_idx"
  end
end
