defmodule OpenAperture.Manager.Controllers.ProductDeploymentPlans do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Queries.Product, as: ProductQuery
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Queries.ProductDeploymentPlan, as: PDPQuery

  @sendable_fields [:id, :product_id, :name, :inserted_at, :updated_at]

  # GET /products/:product_name/deployment_plans
  def index(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlan")
      product -> json conn, FormatHelper.to_sendable(Repo.all(PDPQuery.get_deployment_plans_for_product(product.id)), @sendable_fields)
    end
  end

  # GET /products/:product_name/deployment_plans/:plan_name
  def show(conn, %{"product_name" => product_name, "plan_name" => plan_name}) do
    case get_product_and_plan_by_name(product_name, plan_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlan")
      {_product, deployment_plan} ->
        conn
        |> json to_sendable(deployment_plan, @sendable_fields)
    end
  end

  # POST /products/:product_name/deployment_plans
  def create(conn, %{"product_name" => product_name} = params) do
    plan_name = params["name"] || ""
    case get_product_and_plan_by_name(product_name, plan_name, :left) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlan")
      {product, nil} ->
        case create_deployment_plan(product, params) do
          {:ok, new_plan} ->
            path = product_deployment_plans_path(Endpoint, :show, product_name, new_plan.name)

            conn
            |> put_resp_header("location", path)
            |> resp :created, ""

          {:invalid, errors} ->
            conn
            |> put_status(:bad_request)
            |> json ResponseBodyFormatter.error_body(errors, "ProductDeploymentPlan")

          {:error, reason} ->
            Logger.error "An error occurred creating a new Product Deployment Plan: #{inspect reason}"
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentPlan")
        end

      {_product, _deployment_plan} ->
        # A deployment plan with this name already exists for this product
        conn
        |> put_status(:conflict)
        |> json ResponseBodyFormatter.error_body(:conflict, "ProductDeploymentPlan")
    end
  end

  # PUT /products/:product_name/deployment_plans/:plan_name
  def update(conn, %{"product_name" => product_name, "plan_name" => plan_name} = params) do
    case get_product_and_plan_by_name(product_name, plan_name, :inner) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlan")
      {product, deployment_plan} ->
        # Check for a conflicting plan
        existing = PDPQuery.get_deployment_plan_by_name(product.id, params["name"])
                   |> Repo.one
        if existing != nil && existing.id != deployment_plan.id do
          # If a conflicting plan exists, blow it away
          ProductDeploymentPlan.destroy(existing)
        end

        changeset = ProductDeploymentPlan.update(deployment_plan, params)
        if changeset.valid? do
          try do
            updated = Repo.update!(changeset)

            path = product_deployment_plans_path(Endpoint, :show, product_name, updated.name)

            conn
            |> put_resp_header("location", path)
            |> resp :no_content, ""

          rescue _e ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentPlan")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductDeploymentPlan")
        end
    end
  end

  # DELETE /products/:product_name/deployment_plans
  def destroy_all_plans(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlan")
      product ->
        case ProductDeploymentPlan.destroy_for_product(product) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentPlan")
        end
    end
  end

  # DELETE /products/:product_name/deployment_plans/:plan_name
  def destroy_plan(conn, %{"product_name" => product_name, "plan_name" => plan_name}) do
    case get_product_and_plan_by_name(product_name, plan_name, :inner) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlan")
      {_product, deployment_plan} ->
        case ProductDeploymentPlan.destroy(deployment_plan) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, _reason} ->
            conn
            |> put_status(:not_found)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentPlan")
        end
    end
  end

  @spec create_deployment_plan(Product.t, Map.t) :: {:ok, ProductDeploymentPlan.t} | {:invalid, [any]} | {:error, any}
  defp create_deployment_plan(product, params) do
    changeset = params
                |> Map.put("product_id", product.id)
                |> ProductDeploymentPlan.new

    if changeset.valid? do
      try do
        plan = Repo.insert!(changeset)
        {:ok, plan}
      rescue e ->
        {:error, e}
      end
    else
      {:invalid, changeset.errors}
    end
  end

  @spec get_product_and_plan_by_name(String.t, String.t, :inner | :left | :right) :: {Product.t, ProductDeploymentPlan.t | nil} | nil
  defp get_product_and_plan_by_name(product_name, plan_name, join_type \\ :inner) do
    product_name = URI.decode(product_name)
    plan_name = URI.decode(plan_name)

    Product
    |> join(join_type, [p], pdp in ProductDeploymentPlan, pdp.product_id == p.id and pdp.name == ^plan_name)
    |> where([p, pdp], fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> select([p, pdp], {p, pdp})
    |> Repo.one
  end

  @spec get_product_by_name(String.t) :: Product.t | nil
  defp get_product_by_name(product_name) do
    product_name
    |> URI.decode
    |> ProductQuery.get_by_name
    |> Repo.one
  end
end