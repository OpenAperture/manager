defmodule OpenAperture.Manager.Controllers.ProductDeployments do
  require Logger

  use OpenAperture.Manager.Web, :controller
  use Timex

  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeployment
  #alias OpenAperture.Manager.DB.Queries.ProductDeployment, as: DeploymentQuery
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Queries.ProductEnvironment, as: EnvironmentQuery

  alias OpenAperture.ProductDeploymentOrchestratorApi.Request, as: OrchestratorRequest
  alias OpenAperture.ProductDeploymentOrchestratorApi.ProductDeploymentOrchestrator.Publisher, as: OrchestratorPublisher

  @deployment_sendable_fields [:id, :product_id, :product_deployment_plan_id, :product_environment_id, :execution_options, :completed, :duration, :output, :inserted_at, :updated_at]
  @deployment_steps_sendable_fields [:id, :product_deployment_plan_step_id, :product_deployment_plan_step_type, :duration, :successful, :execution_options, :output, :sequence, :inserted_at, :updated_at]

  # GET /products/:product_name/deployments
  def swaggerdoc_index, do: %{
    description: "Retrieve all ProductDeployments for a Product",
    response_schema: %{"title" => "ProductDeployments", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeployment"}},
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    }]
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t    
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
          page_number = 1
        else
          page_number = Integer.parse(params["page"])
        end

        product_id = product.id
        page = ProductDeployment
          |> where([p], p.product_id == ^product_id)
          |> order_by([p], desc: p.inserted_at)
          |> preload(:product_deployment_plan)
          |> preload(:product_environment)
          |> Repo.paginate(page: page_number)

        json conn, %{deployments: FormatHelper.to_sendable(page.entries, @deployment_sendable_fields), total_pages: page.total_pages, total_deployments: page.total_entries}
    end
  end

  # GET /products/:product_name/deployments/:deployment_id
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific ProductDeployment",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeployment"},
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "deployment_id",
      "in" => "path",
      "description" => "Identifier of the ProductDeployment",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t   
  def show(conn, %{"product_name" => product_name, "deployment_id" => deployment_id}) do
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
      pd -> json conn, FormatHelper.to_sendable(pd, @deployment_sendable_fields)
    end
  end

  # POST /products/:product_name/deployments
  def swaggerdoc_create, do: %{
    description: "Create a ProductDeployment" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The new ProductDeployment",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeployment"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def create(conn, %{"product_name" => product_name, "plan_name" => plan_name, "environment_name" => environment_name} = params) do
    product_name = URI.decode(product_name)

    case get_deployment_plan_by_name(product_name, plan_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "DeploymentPlan")
      {product, plan} ->
        case EnvironmentQuery.get_environment(product_name, environment_name) |> Repo.one do 
          nil -> 
            conn
            |> put_status(:not_found)
            |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironment")
          environment -> 
            execution_options_string = case params["execution_options"] do 
              nil -> "{}"
              options -> Poison.encode!(options)
            end

            new_map = %{
              "product_id" => product.id,
              "product_deployment_plan_id" => plan.id,
              "product_environment_id" => environment.id,
              "execution_options" => execution_options_string,
              "completed" => false
            }

            params = Map.merge(params, new_map)

            Logger.debug("Params #{inspect params}")

            changeset = ProductDeployment.new(params)

            Logger.debug("Changeset: #{inspect changeset}")
            
            if changeset.valid? do
              deployment = Repo.insert!(changeset)

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
  end

  # This clause will only be hit if the request was missing a "plan_name" field
  # POST /products/:product_name/deployments
  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json ResponseBodyFormatter.error_body(:bad_request, "ProductDeployment")
  end

  def swaggerdoc_update, do: %{
    description: "Update a ProductDeployment" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "deployment_id",
      "in" => "path",
      "description" => "Identifier of the ProductDeployment",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated ProductDeployment",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeployment"}
    }]
  }
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t
  def update(conn, %{"product_name" => product_name, "deployment_id" => deployment_id} = params) do 
    product_name = URI.decode(product_name)

    case get_product_deployment(product_name, deployment_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
      deployment ->
        changeset = ProductDeployment.update(deployment, params)
        if changeset.valid? do
          deployment = Repo.update!(changeset)
          path = product_deployments_path(Endpoint, :show, product_name, deployment.id)

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

  # DELETE /products/:product_name/deployments/:deployment_id
  def swaggerdoc_destroy, do: %{
    description: "Delete a ProductDeployment" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "deployment_id",
      "in" => "path",
      "description" => "Identifier of the ProductDeployment",
      "required" => true,
      "type" => "integer"
    }]
  }
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t  
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

  def swaggerdoc_execute, do: %{
    description: "Execute a ProductDeployment" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "id",
      "in" => "path",
      "description" => "Identifier of the ProductDeployment",
      "required" => true,
      "type" => "integer"
    }]
  }
  @spec execute(Plug.Conn.t, [any]) :: Plug.Conn.t
  def execute(conn, %{"product_name" => product_name, "id" => id} = _params) do
    deployment = get_product_deployment(product_name, id)

    cond do
      deployment == nil -> resp(conn, :not_found, "")
      deployment.completed == true -> resp(conn, :conflict, "Workflow has already completed")
      deployment.output != "[]" -> resp(conn, :conflict, "Workflow has already been started")
      true ->
        request = %OrchestratorRequest{}
        request = %{request | deployment: deployment}
        request = %{request | completed: nil}
        request = %{request | product_deployment_orchestration_exchange_id: Configuration.get_current_exchange_id}
        request = %{request | product_deployment_orchestration_broker_id: Configuration.get_current_broker_id}
        request = %{request | product_deployment_orchestration_queue: "product_deployment_orchestrator"}

        case OrchestratorPublisher.execute_orchestration(request) do
          :ok -> 
            path = OpenAperture.Manager.Router.Helpers.workflows_path(Endpoint, :show, id)

            # Set location header
            conn
            |> put_resp_header("location", path)
            |> resp(:accepted, "")
          {:error, reason} -> 
            Logger.error("Error executing Workflow #{id}: #{inspect reason}")
            resp(conn, :internal_server_error, "")            
        end
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
    |> preload(:product_deployment_plan)
    |> preload(:product_environment)
    |> Repo.one
  end

  defp get_product_by_name(product_name) do
    Product
    |> where([p], fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> Repo.one
  end
  
end