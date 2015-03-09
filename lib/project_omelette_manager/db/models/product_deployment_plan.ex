#
# == product_deployment_plan.ex
#
# This module contains the db schema the 'product_deployment_plans' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2015 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Models.ProductDeploymentPlan do
  @required_fields [:product_id, :name]
  @optional_fields []
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "product_deployment_plans" do
    belongs_to :product,                     Models.Product
    has_many :product_deployment_plan_steps, Models.ProductDeploymentPlanStep
    field :name,                             :string
    timestamps
  end
end