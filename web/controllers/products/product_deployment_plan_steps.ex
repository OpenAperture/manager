defmodule OpenAperture.Manager.Controllers.ProductDeploymentPlanSteps do
  require Logger

  use OpenAperture.Manager.Web, :controller

  import OpenAperture.Manager.Controllers.FormatHelper
  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenapertureManager.Repo
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
        |> resp :not_found, ""
    end
  end

  # POST /products/:product_name/deployment_plans/:plan_name/steps
  def create(conn, %{"product_name" => product_name, "plan_name" => plan_name} = params) do
    case get_product_and_plan_by_name(product_name, plan_name) do
      {_, plan} when plan != nil ->
        case create_step(plan.id, params) do
          {:ok, _step} ->
            path = product_deployment_plan_steps_path(Endpoint, :index, product_name, plan_name)
            conn
            |> put_resp_header("location", path)
            |> resp :created, ""
          {:invalid, errors} ->
            conn
            |> put_status(:bad_request)
            |> json %{errors: inspect(errors)}
          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json %{errors: inspect(reason)}
        end
      _ ->
        conn
        |> resp :not_found, ""
    end
  end

  # DELETE /products/:product_name/deployment_plans/:plan_name/steps
  def destroy(conn, %{"product_name" => product_name, "plan_name" => plan_name}) do
    case get_product_and_plan_by_name(product_name, plan_name) do
      {_, plan} when plan != nil ->
        case delete_steps_for_plan(plan.id) do
          :ok ->
            conn
            |> resp :no_content, ""
          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json inspect(reason)
        end
      _ ->
        conn
        |> resp :not_found, ""
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
          new_step = Repo.insert(changeset)
          if step_params["options"] != nil do
            Enum.each(step_params["options"], fn option ->
              option = Map.put(option, "product_deployment_plan_step_id", new_step.id)

              changeset = ProductDeploymentPlanStepOption.new(option)
              if changeset.valid? do
                Repo.insert(changeset)
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

  @spec delete_steps_for_plan(integer) :: :ok | {:error, any}
  defp delete_steps_for_plan(plan_id) do
    result = Repo.transaction(fn ->
      step_query = ProductDeploymentPlanStep
                   |> where([pdps], pdps.product_deployment_plan_id == ^plan_id)

      step_ids = step_query
                 |> select([pdps], pdps.id)
                 |> Repo.all

      options_query = ProductDeploymentPlanStepOption
                      |> where([pdpso], pdpso.product_deployment_plan_step_id in ^step_ids)

      Repo.delete_all(options_query)
      Repo.delete_all(step_query)
    end)

    case result do
      {:ok, _} -> :ok
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

  @spec get_product_and_plan_by_name(String.t, String.t) :: {Product.t | nil, ProductDeploymentPlan.t | nil}
  defp get_product_and_plan_by_name(product_name, plan_name) do
    product_name = URI.decode(product_name)
    plan_name = URI.decode(plan_name)

    Product
    |> join(:left, [p], pdp in ProductDeploymentPlan, pdp.product_id == p.id and fragment("lower(?) = lower(?)", pdp.name, ^plan_name))
    |> where([p, pdp], fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> select([p, pdp], {p, pdp})
    |> Repo.one
  end  
end