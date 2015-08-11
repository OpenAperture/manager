require Logger
defmodule OpenAperture.ErrorView do
  use OpenAperture.Manager.Web, :view

  alias OpenAperture.Manager.Configuration
  alias OpenAperture.ManagerApi
  alias OpenAperture.ManagerApi.SystemEvent  

  def render("404.html", assigns) do
    log_error("[Manager][ErrorView][404]", assigns)
    "Page not found - 404"
  end

  def render("500.html", assigns) do
    log_error("[Manager][ErrorView][500]", assigns, true)
    "Server internal error - 500"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(status, assigns) do
    log_error("[Manager][ErrorView][#{inspect status}]", assigns)
    render "500.html", assigns
  end

  defp log_error(prefix, assigns, generate_event \\ false) do
    try do
      error_map = Map.from_struct(assigns[:reason])
      error_msg = if error_map[:message] != nil do
        "#{prefix} #{assigns[:reason].message}"
      else    
        "#{prefix} #{inspect assigns[:reason]}"
      end
      Logger.error(error_msg)
    
      if generate_event do
        event = %{
        type: :unhandled_exception, 
          severity: :error, 
          data: %{
            component: :manager,
            exchange_id: Configuration.get_current_exchange_id,
            hostname: System.get_env("HOSTNAME")
          },
          message: error_msg
        }       
        SystemEvent.create_system_event!(ManagerApi.get_api, event)      
      end
    catch
      :exit, code   ->
        error_msg = "#{prefix} Exited with code #{inspect code}"
        Logger.error(error_msg)
        event = %{
        type: :unhandled_exception, 
          severity: :error, 
          data: %{
            component: :manager,
            exchange_id: Configuration.get_current_exchange_id,
            hostname: System.get_env("HOSTNAME")
          },
          message: error_msg
        }       
        SystemEvent.create_system_event!(ManagerApi.get_api, event)        
      :throw, value -> 
        error_msg = "#{prefix} Throw called with #{inspect value}"
        Logger.error(error_msg)
        event = %{
        type: :unhandled_exception, 
          severity: :error, 
          data: %{
            component: :manager,
            exchange_id: Configuration.get_current_exchange_id,
            hostname: System.get_env("HOSTNAME")
          },
          message: error_msg
        }       
        SystemEvent.create_system_event!(ManagerApi.get_api, event)        
      what, value   -> 
        error_msg = "#{prefix} Caught #{inspect what} with #{inspect value}"
        Logger.error(error_msg)
        event = %{
        type: :unhandled_exception, 
          severity: :error, 
          data: %{
            component: :manager,
            exchange_id: Configuration.get_current_exchange_id,
            hostname: System.get_env("HOSTNAME")
          },
          message: error_msg
        }       
        SystemEvent.create_system_event!(ManagerApi.get_api, event)        
    end        
  end
end
