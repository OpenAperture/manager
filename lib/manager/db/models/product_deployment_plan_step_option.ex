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
end