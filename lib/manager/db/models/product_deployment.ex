
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
defmodule OpenAperture.Manager.DB.Models.ProductDeployment do
  @required_fields [:product_id, :product_deployment_plan_id]
  @optional_fields [:execution_options, :completed, :duration, :output]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models

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

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
  
end