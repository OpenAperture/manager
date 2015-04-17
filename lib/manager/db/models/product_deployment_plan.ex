defmodule OpenAperture.Manager.DB.Models.ProductDeploymentPlan do
  @required_fields [:product_id, :name]
  @optional_fields []
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models

  schema "product_deployment_plans" do
    belongs_to :product,                     Models.Product
    has_many :product_deployment_plan_steps, Models.ProductDeploymentPlanStep
    field :name,                             :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
end