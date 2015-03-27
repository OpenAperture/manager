defmodule ProjectOmeletteManager.ProductDeploymentPlansController do
  require Logger

  use ProjectOmeletteManager.Web, :controller

  import ProjectOmeletteManager.Controllers.FormatHelper
  import Ecto.Query
  import ProjectOmeletteManager.Router.Helpers

  alias ProjectOmeletteManager.Endpoint
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Queries.Product, as: ProductQuery
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlan
  alias ProjectOmeletteManager.DB.Queries.ProductDeploymentPlan, as: PDPQuery
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlanStep
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlanStepOption

  @sendable_fields [:id, :product_id, :name, :inserted_at, :updated_at]

  plug :action

  # GET /products/:product_name/deployment_plans
  def index(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> resp :not_found, ""
      product ->
        plans = product.id
                |> PDPQuery.get_deployment_plans_for_product
                |> Repo.all
                |> Enum.map(&to_sendable(&1, @sendable_fields))

        conn
        |> json plans
    end
  end

  # GET /products/:product_name/deployment_plans/:plan_name
  def show(conn, %{"product_name" => product_name, "plan_name" => plan_name}) do
    case get_product_and_plan_by_name(product_name, plan_name) do
      nil ->
        conn
        |> resp :not_found, ""
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
        |> resp :not_found, ""
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
            |> json %{errors: inspect(errors)}

          {:error, reason} ->
            Logger.error "An error occurred creating a new Product Deployment Plan: #{inspect reason}"
            conn
            |> resp :internal_server_error, ""
        end

      {_product, _deployment_plan} ->
        # A deployment plan with this name already exists for this product
        conn
        |> put_status(:conflict)
        |> json "A product deployment plan named #{params["name"]} already exists for #{product_name}"
    end
  end

  # PUT /products/:product_name/deployment_plans/:plan_name
  def update(conn, %{"product_name" => product_name, "plan_name" => plan_name} = params) do
    case get_product_and_plan_by_name(product_name, plan_name, :inner) do
      nil ->
        conn
        |> resp :not_found, ""
      {product, deployment_plan} ->
        # Check for a conflicting plan
        existing = PDPQuery.get_deployment_plan_by_name(product.id, params["name"])
                   |> Repo.one
        if existing != nil && existing.id != deployment_plan.id do
          # If a conflicting plan exists, blow it away
          delete_deployment_plan(existing)
        end

        changeset = ProductDeploymentPlan.update(deployment_plan, params)
        if changeset.valid? do
          try do
            updated = Repo.update(changeset)

            path = product_deployment_plans_path(Endpoint, :show, product_name, updated.name)

            conn
            |> put_resp_header("location", path)
            |> resp :no_content, ""

          rescue e ->
            conn
            |> put_status(:internal_server_error)
            |> json %{error: inspect(e)}
          end
        else
          conn
          |> put_status(:bad_request)
          |> json %{error: inspect(changeset.errors)}
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
        |> resp :not_found, ""
      product ->
        case delete_deployment_plans_for_product(product.id) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json %{error: inspect(reason)}
        end
    end
  end

  # DELETE /products/:product_name/deployment_plans/:plan_name
  def destroy_plan(conn, %{"product_name" => product_name, "plan_name" => plan_name}) do
    case get_product_and_plan_by_name(product_name, plan_name, :inner) do
      nil ->
        conn
        |> resp :not_found, ""
      {_product, deployment_plan} ->
        case delete_deployment_plan(deployment_plan) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json %{error: inspect(reason)}
        end
    end
  end

  @spec delete_deployment_plans_for_product(integer) :: :ok | {:error, any}
  defp delete_deployment_plans_for_product(product_id) do
    result = Repo.transaction(fn ->
      plan_ids = ProductDeploymentPlan
                 |> where([pdp], pdp.product_id == ^product_id)
                 |> select([pdp], pdp.id)
                 |> Repo.all

      step_options_query = ProductDeploymentPlanStepOption
                           |> join(:inner, [pdpso], pdps in ProductDeploymentPlanStep, pdpso.product_deployment_plan_step_id == pdps.id)
                           |> where([pdpso, pdps], pdps.product_deployment_plan_id in ^plan_ids)
      steps_query = ProductDeploymentPlanStep
                    |> where([pdps], pdps.product_deployment_plan_id in ^plan_ids)

      plans_query = ProductDeploymentPlan
                    |> where([pdp], pdp.id in ^plan_ids)

      Repo.delete_all(step_options_query)
      Repo.delete_all(steps_query)
      Repo.delete_all(plans_query)
    end)

    case result do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @spec delete_deployment_plan(ProductDeploymentPlan.t) :: :ok | {:error, any}
  defp delete_deployment_plan(plan) do
    result = Repo.transaction(fn ->
      # Delete deployment plan step option, 
      # deployment plan steps, and the deployment plan itself
      step_options_query = ProductDeploymentPlanStepOption
                           |> join(:inner, [pdpso], pdps in ProductDeploymentPlanStep, pdpso.product_deployment_plan_step_id == pdps.id)
                           |> where([pdpso, pdps], pdps.product_deployment_plan_id == ^plan.id)
      step_query = ProductDeploymentPlanStep
                   |> where([pdps], pdps.product_deployment_plan_id == ^plan.id)

      Repo.delete_all(step_options_query)
      Repo.delete_all(step_query)
      Repo.delete(plan)
    end)

    case result do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @spec create_deployment_plan(Product.t, Map.t) :: {:ok, ProductDeploymentPlan.t} | {:invalid, [any]} | {:error, any}
  defp create_deployment_plan(product, params) do
    changeset = params
                |> Map.put("product_id", product.id)
                |> ProductDeploymentPlan.new

    if changeset.valid? do
      try do
        plan = Repo.insert(changeset)
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