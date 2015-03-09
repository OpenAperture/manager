#
# == product_deployment.ex
#
# This module contains the db schema the 'product_deployments' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Models.ProductDeployment do
  @required_fields [:product_id, :product_deployment_plan_id]
  @optional_fields [:execution_options, :completed, :duration, :output]
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "product_deployments" do
    belongs_to :product,                  Models.Product
    belongs_to :product_deployment_plan,  Models.ProductDeploymentPlan
    belongs_to :product_environment,      Models.ProductEnvironment
    has_many   :product_deployment_steps, Models.ProductDeploymentStep
    field :execution_options,             :string
    field :completed,                     :boolean
    field :duration,                      :string
    field :output,                        :string
    timestamps
  end
  
end