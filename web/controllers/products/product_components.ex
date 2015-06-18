defmodule OpenAperture.Manager.Controllers.ProductComponents do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  
  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Queries.Product, as: ProductQuery
  alias OpenAperture.Manager.DB.Models.ProductComponent
  alias OpenAperture.Manager.DB.Models.ProductComponentOption
  alias OpenAperture.Manager.DB.Queries.ProductComponent, as: PCQuery
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter

  @component_sendable_fields [:id, :product_id, :type, :name, :options, :inserted_at, :updated_at]
  @component_option_sendable_fields [:id, :product_component_id, :name, :value, :inserted_at, :updated_at]

  # TODO: authentication
  plug :action

  # GET /products/:product_name/components
  def index(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductComponent")
      product ->
        components = product.id
                     |> PCQuery.get_components_for_product
                     |> Repo.all
                     |> Enum.map(&format_component/1)

        conn
        |> json components
    end
  end

  # GET /products/:product_name/components/:component_name
  def show(conn, %{"product_name" => product_name, "component_name" => component_name}) do
    case get_product_and_component_by_names(product_name, component_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductComponent")
      {_product, product_component} ->
        conn
        |> json format_component(product_component)
    end
  end

  # POST /products/:product_name/components
  def create(conn, %{"product_name" => product_name} = params) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductComponent")
      product ->
        case get_component_by_name(product.id, params["name"]) do
          nil ->
            case create_component(product, params) do
              {:invalid, errors} ->
                conn
                |> put_status(:bad_request)
                |> json ResponseBodyFormatter.error_body(errors, "ProductComponent")
              {:error, _message} ->
                conn
                |> put_status(:internal_server_error)
                |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductComponent")
              {:ok, new_component} ->
                conn
                |> put_resp_header("location", product_components_path(Endpoint, :show, product_name, URI.encode(new_component.name)))
                |> resp :created, ""
            end
          _pc ->
            # A component with this name already exists for the product.
            conn
            |> put_status(:conflict)
            |> json ResponseBodyFormatter.error_body(:conflict, "ProductComponent")
        end
    end
  end

  # PUT /products/:product_name/components/:component_name
  def update(conn, %{"product_name" => product_name, "component_name" => component_name} = params) do
    case get_product_and_component_by_names(product_name, component_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductComponent")
      {product, _product_component} ->
        # according to the current implementation in the old build server, the correct
        # way to "update" the component is to just blow it away and build a new one, so
        # i guess let's do that...

        # Look for a component with the new name
        existing = get_component_by_name(product.id, params["component_name"])
        result = if existing != nil do
          # If a component with this name exists, kill it with fire!
          ProductComponent.destroy(existing)
        else
          :ok
        end

        case result do
          :ok -> 
            case create_component(product, params) do
              {:invalid, errors} ->
                conn
                |> put_status(:bad_request)
                |> json ResponseBodyFormatter.error_body(errors, "ProductComponent")
              {:error, reason} ->
                Logger.error(reason)
                conn
                |> put_status(:internal_server_error)
                |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductComponent")
              {:ok, new_component} ->
                conn
                |> put_resp_header("location", product_components_path(Endpoint, :show, product_name, URI.encode(new_component.name)))
                |> resp :no_content, ""
            end
          {:error, reason} ->
            Logger.error(reason)
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductComponent")
        end
    end
  end

  # DELETE /products/:product_name/components/
  def destroy(conn, %{"product_name" => product_name}) do
    product_name
    |> get_product_by_name
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductComponent")
      product ->
        case ProductComponent.destroy_for_product(product) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, reason} ->
            Logger.error(reason)
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductComponent")
        end
    end
  end

  # DELETE /products/:product_name/components/:component_name
  def destroy_component(conn, %{"product_name" => product_name, "component_name" => component_name}) do
    case get_product_and_component_by_names(product_name, component_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductComponent")
      {_product, product_component} ->
        case ProductComponent.destroy(product_component) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductComponent")
        end
    end
  end

  @spec create_component(Product.t, Map.t) :: {:ok, ProductComponent.t} | {:invalid, [any]} | {:error, any}
  defp create_component(product, params) do
    # TODO: Scaffolding not currently supported
    # options = params["options"] || []
    # source_repo = Enum.find_value(options, fn map ->
    #   if map["name"] == "source_repo" do
    #     map["value"]
    #   else
    #     false
    #   end
    # end)

    # stack = if params["scaffold_options"] != nil, do: params["scaffold_options"]["stack"], else: nil

    # scaffold_result = if source_repo != nil && stack != nil do
    #   Scaffold.create(source_repo, stack)
    # else
    #   {:ok, nil}
    # end
    scaffold_result = {:ok, nil}

    case scaffold_result do
      {:ok, _repo} ->
        params = Map.put(params, "product_id", product.id)
        
        changeset = ProductComponent.new(params)

        if changeset.valid? do
          result = Repo.transaction(fn ->
            new_component = Repo.insert(changeset)

            options = params["options"] || []

            case create_component_options(new_component.id, options) do
              {:ok, _options} -> new_component
              {:error, error} -> Repo.rollback(error)
            end
          end)

          case result do
            {:error, {:invalid, errors}} -> {:invalid, errors}
            # `other` will be either `{:ok, new_component}` or
            # `{:error, some_database_error}`
            other -> other 
          end
        else
          {:invalid, changeset.errors}
        end

      error -> error
    end
  end

  @spec create_component_options(integer, [Map]) :: {:ok, [ProductComponentOption.t]} | {:error, any}
  defp create_component_options(component_id, options) do
    Repo.transaction(fn ->
      Enum.map(options, fn option ->
        option = Map.put(option, "product_component_id", component_id)
        changeset = ProductComponentOption.new(option)
        if changeset.valid? do
          Repo.insert(changeset)
        else
          # If the option isn't valid, we need to kill the transaction
          # and return the validation info to report to the user
          Repo.rollback({:invalid, changeset.errors})
        end
      end)
    end)
  end

  @spec format_component(ProductComponent.t) :: Map.t
  defp format_component(component) do
    options = component.product_component_options
              |> Enum.map(&(to_sendable(&1, @component_option_sendable_fields)))

    component
    |> to_sendable(@component_sendable_fields)
    |> Map.put(:options, options)
  end

  @spec get_product_by_name(String.t) :: Product.t | nil
  defp get_product_by_name(product_name) do
    product_name
    |> URI.decode
    |> ProductQuery.get_by_name
    |> Repo.one
  end

  @spec get_product_and_component_by_names(String.t, String.t) :: {Product.t, ProductComponent.t} | nil
  defp get_product_and_component_by_names(product_name, component_name) do
    product_name = URI.decode(product_name)
    component_name = URI.decode(component_name)

    ProductComponent
    |> preload(:product_component_options)
    |> join(:inner, [pc], p in Product, pc.product_id == p.id)
    |> where([pc, p], fragment("lower(?) = lower(?)", pc.name, ^component_name) and fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> select([pc, p], {p, pc})
    |> Repo.one
  end

  @spec get_component_by_name(integer, String.t) :: ProductComponent.t
  defp get_component_by_name(product_id, component_name) do
    # guard against nil
    component_name = component_name || ""

    ProductComponent
    |> where([pc], pc.product_id == ^product_id)
    |> where([pc], fragment("lower(?) = lower(?)", pc.name, ^component_name))
    |> Repo.one
  end
end