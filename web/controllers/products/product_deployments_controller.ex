defmodule ProjectOmeletteManager.ProductDeploymentsController do
  require Logger

  use ProjectOmeletteManager.Web, :controller

  import ProjectOmeletteManager.Controllers.FormatHelper
  import Ecto.Query
  import ProjectOmeletteManager.Router.Helpers

  alias ProjectOmeletteManager.Endpoint
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductDeployment
  alias ProjectOmeletteManager.DB.Queries.ProductDeployment, as: DeploymentQuery
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlan
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentStep

  @deployment_sendable_fields [:id, :product_id, :product_deployment_plan_id, :product_environment_id, :execution_options, :completed, :duration, :output, :inserted_at, :updated_at]
  @deployment_steps_sendable_fields [:id, :product_deployment_plan_step_id, :product_deployment_plan_step_type, :duration, :successful, :execution_options, :output, :sequence, :inserted_at, :updated_at]

  plug :action

  # GET /products/:product_name/deployments
  def index(conn, %{"product_name" => product_name}) do
    product_name
    |> URI.decode
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> resp :not_found, ""
      product ->
        deployments = product.id
                      |> DeploymentQuery.get_deployments
                      |> Repo.all
                      |> Enum.map(&to_sendable(&1, @deployment_sendable_fields))

        conn
        |> json deployments
    end
  end

  # GET /products/:product_name/deployments/:deployment_id
  def show(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> resp :not_found, ""
      pd ->
        conn
        |> json to_sendable(pd, @deployment_sendable_fields)
    end
  end

  # POST /products/:product_name/deployments
  def create(conn, %{"product_name" => product_name, "plan_name" => plan_name} = params) do
    product_name = URI.decode(product_name)

    case get_deployment_plan_by_name(product_name, plan_name) do
      nil ->
        conn
        |> resp :not_found, ""
      {product, plan} ->
        execution_options_string = params["execution_options"] || ""
                                   |> Poison.encode!

        new_map = %{
          "product_id" => product.id,
          "product_deployment_plan_id" => plan.id,
          "execution_options" => execution_options_string,
          "completed" => false
        }

        params = Map.merge(params, new_map)

        changeset = ProductDeployment.new(params)
        if changeset.valid? do
          deployment = Repo.insert(changeset)

          # TODO: Execute deployment plan
          # DeploymentPlan.execute(%{
          # deployment: deployment,
          # deployment_id: deployment.id,
          # product: product,
          # plan: plan,
          # execution_options: params["execution_options"]
          # })

          path = product_deployments_path(Endpoint, :show, product_name, deployment.id)
          conn
          |> put_resp_header("location", path)
          |> resp :created, ""
        else
          conn
          |> put_status(:bad_request)
          |> json %{error: inspect(changeset.errors)}
        end

    end

  end

  # This clause will only be hit if the request was missing a "plan_name" field
  # POST /products/:product_name/deployments
  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json %{error: "plan_name required"}
  end

  # DELETE /products/:product_name/deployments/:deploymen_id
  def destroy(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> resp :not_found, ""
      pd ->
        result = Repo.transaction(fn ->
          steps_query = ProductDeploymentStep
                        |> where([pdps], pdps.product_deployment_id == ^pd.id)

          Repo.delete_all(steps_query)
          Repo.delete(pd)
        end)

        case result do
          {:ok, _} ->
            conn
            |> resp :no_content, ""
          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json %{error: inspect(reason)}
        end
    end
  end

  # GET /products/:product_name/deployments/:deployment_id/steps
  def index_steps(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> resp :not_found, ""
      pd ->
        steps = ProductDeploymentStep
                |> where([pdps], pdps.product_deployment_id == ^pd.id)
                |> Repo.all
                |> Enum.map(&(to_sendable(&1, @deployment_steps_sendable_fields)))
        conn
        |> json steps
    end
  end

  defp get_deployment_plan_by_name(product_name, deployment_plan_name) do
    ProductDeploymentPlan
    |> join(:inner, [pdp], p in Product, pdp.product_id == p.id and fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> where([pdp, p], fragment("lower(?) = lower(?)", pdp.name, ^deployment_plan_name))
    |> select([pdp, p], {p, pdp})
    |> Repo.one
  end

  defp get_product_deployment(product_name, deployment_id) do
    ProductDeployment
    |> join(:inner, [pd], p in Product, pd.product_id == p.id and fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> where([pd, p], pd.id == ^deployment_id)
    |> Repo.one
  end

  defp get_product_by_name(product_name) do
    Product
    |> where([p], fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> Repo.one
  end
  
end