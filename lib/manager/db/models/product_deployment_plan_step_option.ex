defmodule OpenAperture.Manager.DB.Models.ProductDeploymentPlanStepOption do
  @required_fields [:product_deployment_plan_step_id, :name]
  @optional_fields [:value]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep

  schema "product_deployment_plan_step_options" do
    belongs_to :product_deployment_plan_step,     ProductDeploymentPlanStep
    field :name,                                  :string
    field :value,                                 :string    
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

  def destroy_for_deployment_plan_step(pdps), do: destroy_for_association(pdps, :product_deployment_plan_step_options)

  def destroy(pdps) do
    Repo.delete(pdps)
  end
end