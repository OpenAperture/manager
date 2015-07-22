defmodule OpenAperture.Manager.Controllers.ProductDeployments do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeployment
  # alias OpenAperture.Manager.DB.Queries.ProductDeployment, as: DeploymentQuery
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentStep

  # alias OpenAperture.ProductDeploymentOrchestratorApi.Request, as: OrchestratorRequest
  # alias OpenAperture.ProductDeploymentOrchestratorApiu.ProductDeploymentOrchestrator.Publisher, as: OrchestratorPublisher

  @deployment_sendable_fields [:id, :product_id, :product_deployment_plan_id, :product_environment_id, :execution_options, :completed, :duration, :output, :inserted_at, :updated_at]
  @deployment_steps_sendable_fields [:id, :product_deployment_plan_step_id, :product_deployment_plan_step_type, :duration, :successful, :execution_options, :output, :sequence, :inserted_at, :updated_at]

  plug :action

  # GET /products/:product_name/deployments
  def index(conn, %{"product_name" => product_name} = params) do
    product_name
    |> URI.decode
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
      product ->
        if params["page"] == nil do 
          params = Map.put(params, "page", 0)
        end

        product_id = product.id

        pd_query = from pd in ProductDeployment,
                where: pd.product_id == ^product_id,
                order_by: [pd.inserted_at],
                select: pd

        page = pd_query |> Repo.paginate(page: params["page"])
                

        deployments = page.entries
        |> Enum.map(&to_sendable(&1, @deployment_sendable_fields))

        conn
        |> json %{deployments: deployments, total_pages: page.total_pages, total_deployments: page.total_entries}
    end
  end

  # GET /products/:product_name/deployments/:deployment_id
  def show(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
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
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
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
          deployment = Repo.insert!(changeset)

          #TODO: Execute deployment plan
          DeploymentPlan.execute(%{
          deployment: deployment,
          deployment_id: deployment.id,
          product: product,
          plan: plan,
          execution_options: params["execution_options"]
          })

          path = product_deployments_path(Endpoint, :show, product_name, deployment.id)
          conn
          |> put_resp_header("location", path)
          |> resp :created, ""
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductDeployment")
        end

    end

  end

  # This clause will only be hit if the request was missing a "plan_name" field
  # POST /products/:product_name/deployments
  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json ResponseBodyFormatter.error_body(:bad_request, "ProductDeployment")
  end

  # DELETE /products/:product_name/deployments/:deploymen_id
  def destroy(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
      pd ->
        result = ProductDeployment.destroy(pd)

        case result do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeployment")
        end
    end
  end

  # GET /products/:product_name/deployments/:deployment_id/steps
  def index_steps(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
      pd ->
        steps = ProductDeploymentStep
                |> where([pdps], pdps.product_deployment_id == ^pd.id)
                |> Repo.all
                |> Enum.map(&(to_sendable(&1, @deployment_steps_sendable_fields)))
        conn
        |> json steps
    end
  end

  # @spec execute(term, [any]) :: term
  # def execute(conn, %{"id" => id} = params) do
  #   raw_workflow = get_workflow(id)

  #   cond do
  #     raw_workflow == nil -> resp(conn, :not_found, "")
  #     raw_workflow.workflow_completed == true -> resp(conn, :conflict, "Workflow has already completed")
  #     raw_workflow.current_step != nil -> resp(conn, :conflict, "Workflow has already been started")
  #     true ->
  #       payload = List.first(convert_raw_workflows([raw_workflow]))
  #       if params["force_build"] != nil do
  #         payload = Map.put(payload, :force_build, params["force_build"])
  #       end

  #       build_messaging_exchange_id = to_string(params["build_messaging_exchange_id"])
  #       if String.length(build_messaging_exchange_id) > 0 do
  #         payload = case Integer.parse(build_messaging_exchange_id) do
  #           {messaging_exchange_id, _} -> Map.put(payload, :build_messaging_exchange_id, messaging_exchange_id)
  #           :error -> payload
  #         end
  #       end

  #       deploy_messaging_exchange_id = to_string(params["deploy_messaging_exchange_id"])
  #       if String.length(deploy_messaging_exchange_id) > 0 do
  #         payload = case Integer.parse(deploy_messaging_exchange_id) do
  #           {messaging_exchange_id, _} -> Map.put(payload, :deploy_messaging_exchange_id, messaging_exchange_id)
  #           :error -> payload
  #         end
  #       end        
                
  #       request = OrchestratorRequest.from_payload(payload)
  #       request = %{request | notifications_exchange_id: Configuration.get_current_exchange_id}
  #       request = %{request | notifications_broker_id: Configuration.get_current_broker_id}
  #       request = %{request | workflow_orchestration_exchange_id: Configuration.get_current_exchange_id}
  #       request = %{request | workflow_orchestration_broker_id: Configuration.get_current_broker_id}
  #       request = %{request | orchestration_queue_name: "workflow_orchestration"}

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