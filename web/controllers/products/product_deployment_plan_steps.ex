defmodule OpenAperture.Manager.Controllers.ProductDeploymentPlanSteps do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep
  alias OpenAperture.Manager.DB.Queries.ProductDeploymentPlanStep, as: StepQuery
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStepOption

  @step_sendable_fields   [:id, :type, :on_success_step_id, :on_failure_step_id, :options, :inserted_at, :updated_at]
  @option_sendable_fields [:id, :product_deployment_plan_step_id, :name, :value, :inserted_at, :updated_at]

  plug :action

  # GET /products/:product_name/deployment_plans/:plan_name/steps
  def index(conn, %{"product_name" => product_name, "plan_name" => plan_name}) do
    case get_product_and_plan_by_name(product_name, plan_name) do
      {_, plan} when plan != nil ->
        plan.id
        |> StepQuery.get_steps_for_plan
        |> Repo.all
        |> case do
          [] ->
            conn
            |> resp :no_content, ""
          steps ->
            hierarchy = steps
                        |> Enum.map(&format_step/1)
                        |> ProductDeploymentPlanStep.to_hierarchy

            conn
            |> json hierarchy
        end
      _ ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlanStep")
    end
  end

  # POST /products/:product_name/deployment_plans/:plan_name/steps
  def create(conn, %{"product_name" => product_name, "plan_name" => plan_name} = params) do
    case get_product_and_plan_by_name(product_name, plan_name) do
      {_, plan} when plan != nil ->
        case create_step(plan.id, params) do
          {:ok, step} ->
            path = product_deployment_plan_steps_path(Endpoint, :index, product_name, plan_name)
            if params["parent_step_id"] != nil and params["step_case"] != nil do 
              case Repo.get(ProductDeploymentPlanStep, params["parent_step_id"]) do
                nil ->
                  conn
                  |> put_status(:bad_request)
                  |> json ResponseBodyFormatter.error_body("{'msg': 'parent step not found'}", "ProductDeploymentPlanStep")
                parent_step ->
                  case params["step_case"] do 
                    "success" ->
                      params = %{on_success_step_id: step.id}
                    "failure" ->
                      params = %{on_failure_step_id: step.id}
                    _ ->
                      params = %{}
                  end

                  Map.put(params, :product_deployment_plan_step_options, parent_step.product_deployment_plan_step_options) 
                  changeset = ProductDeploymentPlanStep.update(parent_step, params)
                  if changeset.valid? do
                    Repo.update!(changeset)
                    conn
                    |> put_resp_header("location", path)
                    |> resp :created, ""
                  else
                    conn
                    |> put_status(:bad_request)
                    |> json ResponseBodyFormatter.error_body(changeset.errors, "ProductDeploymentPlanStep")
                  end
              end
            else 
              conn
              |> put_resp_header("location", path)
              |> resp :created, ""
            end
          {:invalid, errors} ->
            conn
            |> put_status(:bad_request)
            |> json ResponseBodyFormatter.error_body(errors, "ProductDeploymentPlanStep")
          {:error, reason} ->
            Logger.error(reason)
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentPlanStep")
        end
      _ ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlanStep")
    end
  end

  # PUT "/products/:product_name/deployment_plans/:plan_name/steps/:step_id"
  def update(conn, %{"product_name" => product_name, "plan_name" => plan_name, "step_id" => step_id} = params) do
    case Repo.get(ProductDeploymentPlanStep, step_id) do
      nil ->
        conn
        |> resp :not_found, ""
      step ->
        result = Repo.transaction(fn ->
          try do
            changeset = ProductDeploymentPlanStep.update(step, params)
            if changeset.valid? do
              Repo.update!(changeset)
              ProductDeploymentPlanStepOption.destroy_for_deployment_plan_step(step)
              if params["options"] != nil do
                Enum.each(params["options"], fn option ->
                  option = Map.put(option, "product_deployment_plan_step_id", step.id)
                  changeset = ProductDeploymentPlanStepOption.new(option)
                  if changeset.valid? do
                    Repo.insert!(changeset)
                  else
                    throw({:invalid, changeset.errors})
                  end
                end)
              end
            else
              throw({:invalid, changeset.errors})
            end
          catch
            {:invalid, errors} ->
              Repo.rollback({:invalid, errors})
            {:error, error} ->
              Repo.rollback(error)
          end
        end)
        case result do
          {:ok, _} ->
            conn
            |> put_resp_header("location", product_deployment_plans_path(Endpoint, :show, product_name, plan_name))
            |> resp :no_content, ""
          {:invalid, reason} ->
            conn
            |> put_status(:bad_request)
            |> json inspect(reason)
          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json inspect(reason)
        end
    end
  end

  # DELETE /products/:product_name/deployment_plans/:plan_name/steps/:plan_id
  # Deletes SINGLE deployment plan step and all descending children instead of all steps in a plan.
  def destroy(conn, %{"product_name" => product_name, "plan_name" => plan_name, "step_id" => step_id}) do
    case Repo.get(ProductDeploymentPlanStep, step_id) do
      step when step != nil ->
        #If step has parent step update the reference to nil to maintain integrity
        int_id = String.to_integer(step_id)
        case StepQuery.get_parent_step(step_id) |> Repo.one  do 
          parent_step = %ProductDeploymentPlanStep{on_success_step_id: ^int_id} ->
            params = %{"product_name" => product_name, "plan_name" => plan_name, "step_id" => parent_step.id, "on_success_step_id" => nil}
            changeset = ProductDeploymentPlanStep.update(parent_step, params)
            if changeset.valid? do
              Repo.update!(changeset)
            end
          parent_step = %ProductDeploymentPlanStep{on_failure_step_id: ^int_id} ->
            params = %{"product_name" => product_name, "plan_name" => plan_name, "step_id" => parent_step.id, "on_failure_step_id" => nil}
            changeset = ProductDeploymentPlanStep.update(parent_step, params)
            if changeset.valid? do
              Repo.update!(changeset)
            end
          nil ->
        end

        #Delete all children
        result =  Repo.transaction(fn ->
          recursive_step_delete(step.id)
        end)

        case result do
          {:ok, _} ->
            conn
            |> resp :no_content, ""
          {:error, reason} ->
            Logger.error(reason)
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentPlanStep")
        end
      _ ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlanStep")
    end
  end

  # DELETE /products/:product_name/deployment_plans/:plan_name/steps
  def destroy(conn, %{"product_name" => product_name, "plan_name" => plan_name}) do
    case get_product_and_plan_by_name(product_name, plan_name) do
      {_, plan} when plan != nil ->
        case ProductDeploymentPlanStep.destroy_for_deployment_plan(plan) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, reason} ->
            Logger.error(reason)
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "ProductDeploymentPlanStep")
        end
      _ ->
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "ProductDeploymentPlanStep")
    end
  end

  @spec create_step(integer, Map.t) :: {:ok, ProductDeploymentPlanStep.t} | {:invalid, [any]} | {:error, any}
  defp create_step(plan_id, step_params) do
    # recursively create steps
    result = Repo.transaction(fn ->
      try do
        success_step_id = if step_params["on_success_step"] != nil do
          case create_step(plan_id, step_params["on_success_step"]) do
            {:ok, step} -> step.id
            other -> throw(other)
          end
        else
          nil
        end

        failure_step_id = if step_params["on_failure_step"] != nil do
          case create_step(plan_id, step_params["on_failure_step"]) do
            {:ok, step} -> step.id
            other -> throw(other)
          end
        else
          nil
        end

        # If we're here, then recursively creating the success and failure steps succeeded...
        fields = %{
          "product_deployment_plan_id" => plan_id,
          "on_success_step_id" => success_step_id,
          "on_failure_step_id" => failure_step_id}

        changeset = step_params
                    |> Map.merge(fields)
                    |> ProductDeploymentPlanStep.new

        if changeset.valid? do
          new_step = Repo.insert!(changeset)
          if step_params["options"] != nil do
            Enum.each(step_params["options"], fn option ->
              option = Map.put(option, "product_deployment_plan_step_id", new_step.id)

              changeset = ProductDeploymentPlanStepOption.new(option)
              if changeset.valid? do
                Repo.insert!(changeset)
              else
                throw({:invalid, changeset.errors})
              end
            end)
          end

          new_step
        else
          throw({:invalid, changeset.errors})
        end
      catch
        {:invalid, errors} ->
          Repo.rollback({:invalid, errors})
        {:error, error} ->
          Repo.rollback(error)
      end
    end)

    case result do
      {:ok, step} -> {:ok, step}
      {:error, {:invalid, reason}} -> {:invalid, reason}
      error -> error
    end
  end

  @spec format_step(ProductDeploymentPlanStep.t) :: Map.t
  defp format_step(step) do
    options = step.product_deployment_plan_step_options
              |> Enum.map(&format_option/1)

    formatted_step = to_sendable(step, @step_sendable_fields)
    Map.put(formatted_step, :options, options)
  end

  @spec format_option(ProductDeploymentPlanStepOption.t) :: Map.t
  defp format_option(step_option) do
    step_option
    |> to_sendable(@option_sendable_fields)
  end

  @spec get_product_and_plan_by_name(String.t, String.t) :: Model.t | nil
  defp get_product_and_plan_by_name(product_name, plan_name) do
    product_name = URI.decode(product_name)
    plan_name = URI.decode(plan_name)

    Product
    |> join(:left, [p], pdp in ProductDeploymentPlan, pdp.product_id == p.id and fragment("lower(?) = lower(?)", pdp.name, ^plan_name))
    |> where([p, pdp], fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> select([p, pdp], {p, pdp})
    |> Repo.one
  end  

  defp recursive_step_delete(plan_step_id) when is_nil(plan_step_id) do
    :ok
  end

  defp recursive_step_delete(plan_step_id) do
    #Delete self
    plan_step = Repo.get(ProductDeploymentPlanStep, plan_step_id)
    ProductDeploymentPlanStep.destroy(plan_step)

    #Delete children
    recursive_step_delete(plan_step.on_success_step_id)
    recursive_step_delete(plan_step.on_failure_step_id)
  end
end