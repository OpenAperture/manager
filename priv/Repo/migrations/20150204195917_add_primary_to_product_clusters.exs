defmodule ProjectOmeletteManager.Repo.Migrations.AddPrimaryToProductClusters do
  use Ecto.Migration

  def up do
    [
      "ALTER TABLE product_clusters ADD primary_ind boolean"
    ]
  end

  def down do
    [
      "ALTER TABLE product_clusters DROP COLUMN primary_ind"
    ]
  end
end
