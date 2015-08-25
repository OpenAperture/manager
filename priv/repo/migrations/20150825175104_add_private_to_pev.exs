defmodule OpenAperture.Manager.Repo.Migrations.AddPrivateToPev do
  use Ecto.Migration

  def change do
    alter table(:product_environmental_variables) do
      add :private, :boolean, null: true
    end  
  end
end
