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
      nil ->
        json conn, []
      steps ->
        IO.inspect(steps)

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

  # POST /products/:product_name/deployments/:deployment_id/steps/:step_id
  def update(conn, %{"deployment_id" => deployment_id, "step_id" => step_id} = params) do 
    case ProductDeploymentStepQuery.get_step_of_deployment(deployment_id, step_id) |> Repo.one do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentStep")
      step ->
        changeset = ProductDeploymentStep.update(step, params)
        if changeset.valid? do
          deployment = Repo.update!(changeset)
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

  # # DELETE /products/:product_name/deployments/:deployment_id
  # def destroy(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
  #   product_name = URI.decode(product_name)

  #   case get_product_deployment(product_name, deployment_id) do
  #     nil ->
  #       conn
  #       |> put_status(:not_found)
  #       |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
  #     pd ->
  #       result = ProductDeployment.destroy(pd)

  #       case result do
  #         :ok ->
  #           conn
  #           |> resp :no_content, ""
  #         {:error, _reason} ->
  #           conn
  #           |> put_status(:internal_server_error)
  #           |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeployment")
  #       end
  #   end
  # end

  # # GET /products/:product_name/deployments/:deployment_id/steps
  # def index_steps(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
  #   product_name = URI.decode(product_name)

  #   case get_product_deployment(product_name, deployment_id) do
  #     nil ->
  #       conn
  #       |> put_status(:not_found)
  #       |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
  #     pd ->
  #       steps = ProductDeploymentStep
  #               |> where([pdps], pdps.product_deployment_id == ^pd.id)
  #               |> Repo.all
  #               |> Enum.map(&(to_sendable(&1, @deployment_steps_sendable_fields)))
  #       conn
  #       |> json steps
  #   end
  # end

  # def execute(conn, %{"product_name" => product_name, "id" => id} = _params) do
  #   deployment = get_product_deployment(product_name, id)

  #   cond do
  #     deployment == nil -> resp(conn, :not_found, "")
  #     deployment.completed == true -> resp(conn, :conflict, "Workflow has already completed")
  #     deployment.output != "[]" -> resp(conn, :conflict, "Workflow has already been started")
  #     true ->
  #       request = %OrchestratorRequest{}
  #       request = %{request | deployment: deployment}
  #       request = %{request | completed: nil}
  #       request = %{request | product_deployment_orchestration_exchange_id: Configuration.get_current_exchange_id}
  #       request = %{request | product_deployment_orchestration_broker_id: Configuration.get_current_broker_id}
  #       request = %{request | product_deployment_orchestration_queue: "product_deployment_orchestrator"}

  #       case OrchestratorPublisher.execute_orchestration(request) do
  #         :ok -> 
  #           path = OpenAperture.Manager.Router.Helpers.workflows_path(Endpoint, :show, id)

  #           # Set location header
  #           conn
  #           |> put_resp_header("location", path)
  #           |> resp(:accepted, "")
  #         {:error, reason} -> 
  #           Logger.error("Error executing Workflow #{id}: #{inspect reason}")
  #           resp(conn, :internal_server_error, "")            
  #       end
  #   end
  # end
  
end