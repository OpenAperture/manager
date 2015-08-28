defmodule OpenAperture.Manager.Repo.Migrations.EncryptPevValues do
  use Ecto.Migration
  alias OpenAperture.Manager.Repo

  require Repo

  def change do
    alter table(:product_environmental_variables) do
      add :value_keyname, :string, null: true
    end
  end
end
