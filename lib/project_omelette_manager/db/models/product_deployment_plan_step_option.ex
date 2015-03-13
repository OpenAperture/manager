#
# == product_deployment_plan_step_option.ex
#
# This module contains the db schema the 'product_deployment_plan_step_options' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2015 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Models.ProductDeploymentPlanStepOption do
  @required_fields [:product_deployment_plan_step_id, :name]
  @optional_fields [:value]
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlanStep

  schema "product_deployment_plan_step_options" do
    belongs_to :product_deployment_plan_step,     ProductDeploymentPlanStep
    field :name,                                  :string
    field :value,                                 :string    
    timestamps
  end

  defp validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
end