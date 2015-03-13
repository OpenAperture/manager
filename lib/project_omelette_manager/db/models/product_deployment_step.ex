#
# == product_deployment_step.ex
#
# This module contains the db schema the 'product_deployment_steps' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Models.ProductDeploymentStep do
  @required_fields [:product_deployment_id]
  @optional_fields [:product_deployment_plan_step_id, :product_deployment_plan_step_type, :duration, :successful,
                    :execution_options, :output, :sequence]
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models.ProductDeployment

  #product_deployment_plan_step_id and product_deployment_plan_step_type
  #are not a hard dependencies, we can delete steps w/o having to clear history
  schema "product_deployment_steps" do
    belongs_to :product_deployment,            ProductDeployment
    field :product_deployment_plan_step_id,    :integer 
    field :product_deployment_plan_step_type,  :string 
    field :duration,                           :string
    field :successful,                         :boolean
    field :execution_options,                  :string
    field :output,                             :string
    field :sequence,                           :integer
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
end