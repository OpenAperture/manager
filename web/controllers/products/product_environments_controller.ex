defmodule ProjectOmeletteManager.ProductEnvironmentsController do
  require Logger

  use ProjectOmeletteManager.Web, :controller

  import ProjectOmeletteManager.Controllers.FormatHelper
  import Ecto.Query
  import ProjectOmeletteManager.Router.Helpers

  alias ProjectOmeletteManager.Endpoint
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Queries.ProductEnvironment, as: EnvQuery

  @sendable_fields [:id, :name, :product_id, :inserted_at, :updated_at]

  plug :action

  # GET products/:product_name/environments
  def index(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> resp :not_found, ""
      product ->
        environments = Enum.map(product.environments, &to_sendable(&1, @sendable_fields))

        conn
        |> json environments
    end
  end

  @spec get_product_by_name(String.t) :: Product.t | nil
  defp get_product_by_name(product_name) do
    product_name = URI.decode(product_name)

    Product
    |> preload(:environments)
    |> where([p], fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> Repo.one
  end
end