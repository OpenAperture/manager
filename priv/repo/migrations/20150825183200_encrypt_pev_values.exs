defmodule OpenAperture.Manager.Repo.Migrations.EncryptPevValues do
  use Ecto.Migration
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.ProductEnvironmentalVariable
  alias OpenAperture.Manager.Controllers.FormatHelper

  require Repo

  def change do
    alter table(:product_environmental_variables) do
      add :value_keyname, :boolean, null: true
    end
    
    ProductEnvironmentalVariable
    |> Repo.all
    |> Enum.map(&updatePEV/1)
  end

  def updatePEV(pev) do
    pev
    |> ProductEnvironmentalVariable.update(%{value: FormatHelper.encrypt_value(pev.value)})
    |> Repo.update
  end
end
