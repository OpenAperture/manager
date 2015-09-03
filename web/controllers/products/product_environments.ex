defmodule OpenAperture.Manager.Controllers.ProductEnvironments do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductEnvironment
  alias OpenAperture.Manager.DB.Queries.ProductEnvironment, as: EnvQuery

  @sendable_fields [:id, :name, :product_id, :inserted_at, :updated_at]

  # GET /products/:product_name/environments
  def swaggerdoc_index, do: %{
    description: "Retrieve all ProductEnvironments",
    response_schema: %{"title" => "ProductEnvironments", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductEnvironment"}},
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    }]
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def index(conn, %{"product_name" => product_name}) do
    product_name
    |> URI.decode
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironment")
      product ->
        environments = Enum.map(product.environments, &to_sendable(&1, @sendable_fields))

        conn
        |> json environments
    end
  end

  # GET /products/:product_name/environments/:environment_name
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific ProductEnvironment",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductEnvironment"},
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "component_name",
      "in" => "path",
      "description" => "Name of the ProductEnvironment",
      "required" => true,
      "type" => "string"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t    
  def show(conn, %{"product_name" => product_name, "environment_name" => environment_name}) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)

    EnvQuery.get_environment(product_name, environment_name)
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironment")
      pe ->
        conn
        |> json to_sendable(pe, @sendable_fields)
    end
  end

  # POST /products/:product_name/environments
  def swaggerdoc_create, do: %{
    description: "Create a ProductEnvironment" ,
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
      "description" => "The new ProductEnvironment",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductEnvironment"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t   
  def create(conn, %{"product_name" => product_name, "name" => environment_name} = _params) do
    product_name = URI.decode(product_name)

    # guard against nil "name" param
    environment_name = environment_name || ""

    Product
    |> join(:left, [p], pe in ProductEnvironment, pe.product_id == p.id and fragment("lower(?) = lower(?)", pe.name, ^environment_name))
    |> where([p, pe], fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> select([p, pe], {p, pe})
    |> Repo.one
    |> case do
      nil ->
        # product not found
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironment")
      {product, nil} ->
        # This is the happy path
        changeset = ProductEnvironment.new(%{name: environment_name, product_id: product.id})
        if changeset.valid? do
          new_env = Repo.insert!(changeset)

          path = product_environments_path(Endpoint, :show, product_name, new_env.name)

          conn
          |> put_resp_header("location", path)
          |> resp :created, ""
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductEnvironment")
        end
      {_product, _env} ->
        # An environment with this name already exists
        conn
        |> put_status(:conflict)
        |> json ResponseBodyFormatter.error_body(:conflict, "ProductEnvironment")
    end
  end

  # we'll only hit this clause if the request didn't supply an environment
  # name, which means it's a bad request
  # POST /products/:product_name/environments
  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json ResponseBodyFormatter.error_body(:bad_request, "ProductEnvironment")
  end

  # PUT /products/:product_name/environments/:environment_name
  def swaggerdoc_update, do: %{
    description: "Update a ProductEnvironment" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "environment_name",
      "in" => "path",
      "description" => "Name of the Environment",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated ProductEnvironment",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.ProductEnvironment"}
    }]
  }  
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t    
  def update(conn, %{"product_name" => product_name, "environment_name" => environment_name} = params) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)

    EnvQuery.get_environment(product_name, environment_name)
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironment")
      pe ->
        changeset = ProductEnvironment.update(pe, params)
        if changeset.valid? do
          # Verify there's not another environment with this name
          {_source, name} = Ecto.Changeset.fetch_field(changeset, :name)
          if environment_name_conflict?(pe.product_id, pe.id, name) do
            conn
            |> put_status(:conflict)
            |> json ResponseBodyFormatter.error_body(:conflict, "ProductEnvironment")
          else
            env = Repo.update!(changeset)
            path = product_environments_path(Endpoint, :show, product_name, env.name)

            conn
            |> put_resp_header("location", path)
            |> resp :no_content, ""
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductEnvironment")
        end
    end
  end

  # DELETE /products/:product_name/environments/:environment_name
   def swaggerdoc_destroy, do: %{
    description: "Delete a ProductEnvironment for a Product" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Name of the Product",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "environment_name",
      "in" => "path",
      "description" => "Name of the Environment",
      "required" => true,
      "type" => "string"
    }]
  }
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t 
  def destroy(conn, %{"product_name" => product_name, "environment_name" => environment_name}) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)

    EnvQuery.get_environment(product_name, environment_name)
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironment")
      pe ->
        case ProductEnvironment.destroy(pe) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductEnvironment")
        end
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

  # Checks if there is another product environment for the given product, with
  # the specified environment name (and a different primary key).
  @spec environment_name_conflict?(integer, integer, String.t) :: boolean
  defp environment_name_conflict?(product_id, environment_id, environment_name) do
    result = ProductEnvironment
             |> where([pe], pe.product_id == ^product_id)
             |> where([pe], pe.id != ^environment_id)
             |> where([pe], fragment("lower(?) = lower(?)", pe.name, ^environment_name))
             |> Repo.one
    result != nil
  end
end