defmodule OpenAperture.Manager.Controllers.Products do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Queries.Product, as: ProductQuery
  alias OpenAperture.Manager.Repo

  @sendable_fields [:id, :name, :updated_at, :inserted_at]
  @updatable_fields [:name]

  # GET "/"
  def swaggerdoc_index, do: %{
    description: "Retrieve all Products",
    response_schema: %{"title" => "Products", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Product"}},
    parameters: []
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def index(conn, _params) do
    products = Repo.all(Product)
               |> Enum.map(&(to_sendable(&1, @sendable_fields)))

    conn
    |> json products
  end

  # GET "/:product_name"
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific Product",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Product"},
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Product name",
      "required" => true,
      "type" => "string"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def show(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "Product")
      product ->
        conn
        |> json to_sendable(product, @sendable_fields)
    end
  end  

  # POST "/"
  def swaggerdoc_create, do: %{
    description: "Create a Product" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Product name",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The new Product",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Product"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def create(conn, %{"name" => product_name} = params) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        changeset = Product.new(params)

        if changeset.valid? do
          product = Repo.insert(changeset)
    
          conn
          |> put_resp_header("location", products_path(Endpoint, :show, product.name))
          |> resp :created, ""
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "Product")
        end      

      _product ->
        conn
        |> put_status(:conflict)
        |> json ResponseBodyFormatter.error_body(:conflict, "Product")
    end
  end

  # DELETE "/:product_name"
  def swaggerdoc_destroy, do: %{
    description: "Delete a Product" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Product name",
      "required" => true,
      "type" => "string"
    }]
  }  
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t  
  def destroy(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "Product")
      product ->
        Product.destroy(product)
        conn
        |> resp :no_content, ""
    end
  end

  # PUT "/:product_name"
  def swaggerdoc_update, do: %{
    description: "Update a Product" ,
    parameters: [%{
      "name" => "product_name",
      "in" => "path",
      "description" => "Product name",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "product_name",
      "in" => "path",
      "description" => "Product name",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated Product",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.Product"}
    }]
  }
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t   
  def update(conn, %{"product_name" => product_name} = params) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "Product")
      product ->
        changeset = Product.update(product, params)
        if changeset.valid? do
          # Validate there isn't already a product with this name
          params["name"]
          |> get_product_by_name
          |> case do
            nil ->
              product = Repo.update(changeset)
              conn
              |> put_resp_header("location", products_path(Endpoint, :show, product.name))
              |> resp :no_content, ""
            _product ->
              conn
              |> put_status(:conflict)
              |> json ResponseBodyFormatter.error_body(:conflict, "Product")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "Product")
        end
    end
  end

  @spec get_product_by_name(String.t) :: Product.t | nil
  defp get_product_by_name(product_name) do
    product_name
    |> URI.decode
    |> ProductQuery.get_by_name
    |> Repo.one
  end
end