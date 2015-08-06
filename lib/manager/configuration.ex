#
# == configuration.ex
#
# This module contains the logic to retrieve configuration from either the environment or configuration files
#
defmodule OpenAperture.Manager.Configuration do

  @doc """
  Method to retrieve the currently assigned exchange id
   
  ## Options
   
  ## Return values

  The exchange identifier
  """ 
  @spec get_current_exchange_id() :: String.t()
  def get_current_exchange_id do
    get_config("EXCHANGE_ID", OpenAperture.Manager, :exchange_id)
  end

  @doc """
  Method to retrieve the currently assigned exchange id
   
  ## Options
   
  ## Return values

  The exchange identifier
  """ 
  @spec get_current_broker_id() :: String.t()
  def get_current_broker_id do
    get_config("BROKER_ID", OpenAperture.Manager, :broker_id)
  end

  @doc """
  Method to retrieve the associated UI's url
   
  ## Options
   
  ## Return values

  The exchange identifier
  """ 
  @spec get_ui_url() :: String.t()
  def get_ui_url do
    get_config("UI_URL", OpenAperture.Manager, :ui_url)
  end
  
  @doc false
  # Method to retrieve a configuration option from the environment or config settings
  # 
  ## Options
  # 
  # The `env_name` option defines the environment variable name
  #
  # The `application_config` option defines the config application name (atom)
  #
  # The `config_name` option defines the config variable name (atom)
  # 
  ## Return values
  # 
  # Value
  # 
  @spec get_config(String.t(), term, term) :: String.t()
  defp get_config(env_name, application_config, config_name) do
    System.get_env(env_name) || Application.get_env(application_config, config_name)
  end  
end