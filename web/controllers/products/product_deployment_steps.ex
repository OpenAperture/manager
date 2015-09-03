defmodule OpenAperture.Manager.Controllers.ProductDeploymentSteps do
  require Logger

  use OpenAperture.Manager.Web, :controller
  use Timex

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Queries.ProductDeployment, as: ProductDeploymentQuery
  alias OpenAperture.Manager.DB.Models.ProductDeploymentStep
  alias OpenAperture.Manager.DB.Queries.ProductDeploymentStep, as: ProductDeploymentStepQuery

  @deployment_sendable_fields [:id, :product_id, :product_deployment_plan_id, :product_environment_id, :execution_options, :completed, :duration, :output, :inserted_at, :updated_at]
  @deployment_steps_sendable_fields [:id, :product_deployment_plan_step_id, :product_deployment_plan_step_type, :duration, :successful, :execution_options, :output, :sequence, :inserted_at, :updated_at]

  # GET /products/:product_name/deployments/:deployment_id/steps
  def swaggerdoc_index, do: %{
    description: "Retrieve all ProductDeploymentSteps for a ProductDeployment",
    response_schema: %{"title" => "ProductDeploymentSteps", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeploymentStep"}},
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
      "description" => "ProductDeployment identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t   
  def index(conn, %{"deployment_id" => deployment_id} = _params) do
    json conn, FormatHelper.to_sendable(Repo.all(ProductDeploymentStepQuery.get_steps_of_deployment(deployment_id)), @deployment_steps_sendable_fields)
  end

  def swaggerdoc_show, do: %{
    description: "Retrieve a ProductDeploymentStep for a ProductDeployment",
    response_schema: %{"title" => "ProductDeploymentSteps", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeploymentStep"}},
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
      "description" => "ProductDeployment identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "step_id",
      "in" => "path",
      "description" => "ProductDeploymentStep identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t 
  def show(conn, %{"product_name" => _product_name, "deployment_id" => deployment_id, "step_id" => step_id} = _params) do
    case ProductDeploymentStepQuery.get_step_of_deployment(deployment_id, step_id) |> Repo.one do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentStep")
      step ->
        json conn, FormatHelper.to_sendable(step, @deployment_steps_sendable_fields)
    end
  end

  # POST /products/:product_name/deployments/:deployment_id/steps
  def swaggerdoc_create, do: %{
    description: "Create a ProductDeploymentStep" ,
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
      "description" => "ProductDeployment identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The new ProductDeploymentStep",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeploymentStep"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t   
  def create(conn, %{"product_name" => product_name, "deployment_id" => deployment_id} = params) do
    product_name = URI.decode(product_name)

    case ProductDeploymentQuery.get_product_and_deployment(product_name, deployment_id) |> Repo.one do 
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeployment")
      {_product, deployment} ->
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
  def swaggerdoc_update, do: %{
    description: "Update a ProductDeploymentStep" ,
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
      "description" => "ProductDeployment identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "step_id",
      "in" => "path",
      "description" => "ProductDeploymentStep identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated ProductDeploymentStep",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductDeploymentStep"}
    }]
  }
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t     
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
  def swaggerdoc_destroy, do: %{
    description: "Delete a ProductDeploymentStep" ,
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
      "description" => "ProductDeployment identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "step_id",
      "in" => "path",
      "description" => "ProductDeploymentStep identifier",
      "required" => true,
      "type" => "integer"
    }]
  }
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t       
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