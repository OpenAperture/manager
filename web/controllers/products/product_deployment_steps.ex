defmodule OpenAperture.Manager.Controllers.ProductDeploymentSteps do
  require Logger

  use OpenAperture.Manager.Web, :controller
  use Timex

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeployment
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentStep
  alias OpenAperture.Manager.DB.Queries.ProductDeploymentStep, as: ProductDeploymentStepQuery
  alias OpenAperture.Manager.DB.Queries.ProductEnvironment, as: EnvironmentQuery

  alias OpenAperture.ProductDeploymentOrchestratorApi.Request, as: OrchestratorRequest
  alias OpenAperture.ProductDeploymentOrchestratorApi.ProductDeploymentOrchestrator.Publisher, as: OrchestratorPublisher

  @deployment_sendable_fields [:id, :product_id, :product_deployment_plan_id, :product_environment_id, :execution_options, :completed, :duration, :output, :inserted_at, :updated_at]
  @deployment_steps_sendable_fields [:id, :product_deployment_plan_step_id, :product_deployment_plan_step_type, :duration, :successful, :execution_options, :output, :sequence, :inserted_at, :updated_at]

  plug :action

  # GET /products/:product_name/deployments/:deployment_id/steps
  def index(conn, %{"deployment_id" => deployment_id} = params) do
    case ProductDeploymentStepQuery.get_steps_of_deployment(deployment_id) |> Repo.all do
      [] ->
        json conn, []
      steps ->
        json conn, steps
    end
  end

  # POST /products/:product_name/deployments/:deployment_id/steps
  def create(conn, %{"product_name" => product_name, "deployment_id" => deployment_id} = params) do
    product_name = URI.decode(product_name)

    query = from pd in ProductDeployment,
      where: pd.id == ^deployment_id,
      select: pd

    case Repo.one(query) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
      deployment -> 
        params = Map.put(params, "product_deployment_id", deployment.id)
        changeset = ProductDeploymentStep.new(params)

        if changeset.valid? do
          step = Repo.insert!(changeset)

          path = "#{step.id}"
          conn
          |> put_resp_header("location", path)
          |> resp :created, ""
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductDeploymentStep")
        end
    end
  end

  # This clause will only be hit if the request was missing a "plan_name" field
  # POST /products/:product_name/deployments/:deployment_id/steps
  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json ResponseBodyFormatter.error_body(:bad_request, "ProductDeployment")
  end

  #PUT /products/:product_name/deployments/:deployment_id/steps/:step_id
  def update(conn, %{"deployment_id" => deployment_id, "step_id" => step_id} = params) do 
    case ProductDeploymentStepQuery.get_step_of_deployment(deployment_id, step_id) |> Repo.one do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentStep")
      step ->
        changeset = ProductDeploymentStep.update(step, params)
        if changeset.valid? do
          Repo.update!(changeset)
          path = "#{step.id}"

          conn
          |> put_resp_header("location", path)
          |> resp :no_content, ""
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductEnvironment")
        end
    end
  end

  # DELETE /products/:product_name/deployments/:deployment_id/steps/:step_id
  def destroy(conn, %{"deployment_id" => deployment_id, "step_id" => step_id}) do
    case ProductDeploymentStepQuery.get_step_of_deployment(deployment_id, step_id) |> Repo.one do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentStep")
      pds ->
        case ProductDeploymentStep.destroy(pds) do   
          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentStep")
          _deleted_pds ->
            conn
            |> resp :no_content, ""
        end
    end
  end
end