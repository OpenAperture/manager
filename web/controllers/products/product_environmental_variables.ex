defmodule OpenAperture.Manager.Controllers.ProductEnvironmentalVariables do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.ProductEnvironmentalVariable
  alias OpenAperture.Manager.DB.Queries.Product, as: ProductQuery
  alias OpenAperture.Manager.DB.Queries.ProductEnvironment, as: EnvQuery
  alias OpenAperture.Manager.DB.Queries.ProductEnvironmentalVariable, as: VarQuery

  @sendable_fields [:id, :product_id, :product_environment_id, :name, :value, :inserted_at, :updated_at]

  plug :action

  # GET /products/:product_name/environments/:environment_name/variables
  def index_environment(conn, %{"product_name" => product_name, "environment_name" => environment_name}) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)

    EnvQuery.get_environment(product_name, environment_name)
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      _ ->
        vars = VarQuery.find_by_product_name_environment_name(product_name, environment_name)
               |> Repo.all
               |> Enum.map(&to_sendable(&1, @sendable_fields))

        conn
        |> json vars
    end
  end

  # GET /products/:product_name/environmental_variables[?coalesced=true]
  def index_default(conn, %{"product_name" => product_name} = params) do
    product_name
    |> URI.decode
    |> ProductQuery.get_by_name
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      _product ->
        coalesced? = params["coalesced"] != nil && String.downcase(params["coalesced"]) == "true"

        query = if coalesced? do
          VarQuery.find_by_product_name(product_name)
        else
          VarQuery.find_by_product_name(product_name, true)
        end

        vars = Repo.all(query)
               |> Enum.map(&to_sendable(&1, @sendable_fields))        

        conn
        |> json vars
    end
  end

  # GET /products/:product_name/environments/:environment_name/variables/:variable_name
  def show_environment(conn, %{"product_name" => product_name, "environment_name" => environment_name, "variable_name" => variable_name}) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)
    variable_name = URI.decode(variable_name)

    query = VarQuery.find_by_product_name_environment_name_variable_name(product_name, environment_name, variable_name)
    case Repo.one(query) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      env_var ->
        conn
        |> json to_sendable(env_var, @sendable_fields)
    end
  end

  # Because, when coalesced=true, this endpoint may return multiple variables,
  # the response body will always be a list, and not a single variable entity.
  # GET /products/:product_name/environmental_variables/:variable_name[?coalesced=true]
  def show_default(conn, %{"product_name" => product_name, "variable_name" => variable_name} = params) do
    product_name = URI.decode(product_name)
    variable_name = URI.decode(variable_name)
    coalesced? = params["coalesced"] != nil && String.downcase(params["coalesced"]) == "true"

    query = if coalesced? do
      VarQuery.find_by_product_name_variable_name(product_name, variable_name)
    else
      VarQuery.find_by_product_name_variable_name(product_name, variable_name, true)
    end

    vars = Repo.all(query)
           |> Enum.map(&to_sendable(&1, @sendable_fields))        

    if vars == [] do
      conn
      |> put_status(:not_found)
      |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
    else
      conn
      |> json vars
    end        
  end

  # POST /products/:product_name/environments/:environment_name/variables
  def create_environment(conn, %{"product_name" => product_name, "environment_name" => environment_name} = params) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)

    EnvQuery.get_environment(product_name, environment_name)
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      pe ->
        ids = %{"product_id" => pe.product_id, "product_environment_id" => pe.id}

        params = Map.merge(params, ids)
        changeset = ProductEnvironmentalVariable.new(params)
        if changeset.valid? do
          # Check for conflict
          {_source, name} = Ecto.Changeset.fetch_field(changeset, :name)
          if environment_variable_name_conflict?(pe.product_id, pe.id, name) do
            conn
            |> put_status(:conflict)
            |> json ResponseBodyFormatter.error_body(:conflict, "ProductEnvironmentalVariable")
          else
            new_var = Repo.insert!(changeset)
            path = product_environmental_variables_path(Endpoint, :show_environment, product_name, environment_name, new_var.name)

            conn
            |> put_resp_header("location", path)
            |> resp :created, ""
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductEnvironmentalVariable")
        end
    end
  end

  # PUT /products/:product_name/environments/:environment_name/variables/:variable_name
  def update_environment(conn, %{"product_name" => product_name, "environment_name" => environment_name, "variable_name" => variable_name} = params) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)
    variable_name = URI.decode(variable_name)

    query = VarQuery.find_by_product_name_environment_name_variable_name(product_name, environment_name, variable_name)
    case Repo.one(query) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      env_var ->
        changeset = ProductEnvironmentalVariable.update(env_var, params)
        if changeset.valid? do
          # Check for conflict
          {_source, name} = Ecto.Changeset.fetch_field(changeset, :name)
          if environment_variable_name_conflict?(env_var.product_id, env_var.product_environment_id, env_var.id, name) do
            conn
            |> put_status(:conflict)
            |> json ResponseBodyFormatter.error_body(:conflict, "ProductEnvironmentalVariable")
          else
            updated_var = Repo.update!(changeset)
            path = product_environmental_variables_path(Endpoint, :show_environment, product_name, environment_name, updated_var.name)

            conn
            |> put_resp_header("location", path)
            |> resp :no_content, ""
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductEnvironmentalVariable")
        end
    end
  end

  # POST /products/:product_name/environmental_variables
  def create_default(conn, %{"product_name" => product_name} = params) do
    product_name
    |> URI.decode
    |> ProductQuery.get_by_name
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      product ->
        ids = %{"product_id" => product.id}
        params = Map.merge(params, ids)
        changeset = ProductEnvironmentalVariable.new(params)
        if changeset.valid? do
          # Check for conflict
          {_source, name} = Ecto.Changeset.fetch_field(changeset, :name)
          if product_variable_name_conflict?(product.id, name) do
            conn
            |> put_status(:conflict)
            |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
          else
            new_var = Repo.insert!(changeset)
            path = product_environmental_variables_path(Endpoint, :show_default, product_name, new_var.name)

            conn
            |> put_resp_header("location", path)
            |> resp :created, ""
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductEnvironmentalVariable")
        end
    end
  end

  # PUT /products/:product_name/environmental_variables/:variable_name
  def update_default(conn, %{"product_name" => product_name, "variable_name" => variable_name} = params) do
    product_name = URI.decode(product_name)
    variable_name = URI.decode(variable_name)

    query = VarQuery.find_by_product_name_variable_name(product_name, variable_name, true)
    case Repo.one(query) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      env_var ->
        changeset = ProductEnvironmentalVariable.update(env_var, params)
        if changeset.valid? do
          # Check for conflict
          {_source, name} = Ecto.Changeset.fetch_field(changeset, :name)
          if product_variable_name_conflict?(env_var.product_id, env_var.id, name) do
            conn
            |> put_status(:conflict)
            |> json ResponseBodyFormatter.error_body(:conflict, "ProductEnvironmentalVariable")
          else
            updated_var = Repo.update!(changeset)
            path = product_environmental_variables_path(Endpoint, :show_default, product_name, updated_var.name)

            conn
            |> put_resp_header("location", path)
            |> resp :no_content, ""
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductEnvironmentalVariable")
        end
    end
  end

  # DELETE /produts/:product_name/environments/:environment_name/variables/:variable_name
  def destroy_environment(conn, %{"product_name" => product_name, "environment_name" => environment_name, "variable_name" => variable_name}) do
    product_name = URI.decode(product_name)
    environment_name = URI.decode(environment_name)
    variable_name = URI.decode(variable_name)

    query = VarQuery.find_by_product_name_environment_name_variable_name(product_name, environment_name, variable_name)
    case Repo.one(query) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      env_var ->
        ProductEnvironmentalVariable.destroy(env_var)
        conn
        |> resp :no_content, ""
    end
  end

  # DELETE /products/:product_name/environmental_variables/:variable_name
  def destroy_default(conn, %{"product_name" => product_name, "variable_name" => variable_name}) do
    product_name = URI.decode(product_name)
    variable_name = URI.decode(variable_name)

    VarQuery.find_by_product_name_variable_name(product_name, variable_name, true)
    |> Repo.one
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductEnvironmentalVariable")
      env_var ->
        ProductEnvironmentalVariable.destroy(env_var)
        conn
        |> resp :no_content, ""
    end
  end

  @spec environment_variable_name_conflict?(integer, integer, String.t) :: boolean
  defp environment_variable_name_conflict?(product_id, environment_id, variable_name) do
    result = ProductEnvironmentalVariable
             |> where([pev], pev.product_id == ^product_id)
             |> where([pev], pev.product_environment_id == ^environment_id)
             |> where([pev], fragment("lower(?) = lower(?)", pev.name, ^variable_name))
             |> Repo.one
    result != nil
  end

  @spec environment_variable_name_conflict?(integer, integer, integer, String.t) :: boolean
  defp environment_variable_name_conflict?(product_id, environment_id, variable_id, variable_name) do
    result = ProductEnvironmentalVariable
             |> where([pev], pev.id != ^variable_id)
             |> where([pev], pev.product_id == ^product_id)
             |> where([pev], pev.product_environment_id == ^environment_id)
             |> where([pev], fragment("lower(?) = lower(?)", pev.name, ^variable_name))
             |> Repo.one
    result != nil
  end

  @spec product_variable_name_conflict?(integer, String.t) :: boolean
  defp product_variable_name_conflict?(product_id, variable_name) do
    result = ProductEnvironmentalVariable
             |> where([pev], pev.product_id == ^product_id)
             |> where([pev], is_nil(pev.product_environment_id))
             |> where([pev], fragment("lower(?) = lower(?)", pev.name, ^variable_name))
             |> Repo.one

    result != nil
  end

  @spec product_variable_name_conflict?(integer, integer, String.t) :: boolean
  defp product_variable_name_conflict?(product_id, variable_id, variable_name) do
    result = ProductEnvironmentalVariable
             |> where([pev], pev.id != ^variable_id)
             |> where([pev], pev.product_id == ^product_id)
             |> where([pev], is_nil(pev.product_environment_id))
             |> where([pev], fragment("lower(?) = lower(?)", pev.name, ^variable_name))
             |> Repo.one

    result != nil
  end
end