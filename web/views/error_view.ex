require Logger
defmodule OpenAperture.ErrorView do
  use OpenAperture.Manager.Web, :view

  def render("404.html", assigns) do
    log_error("[Manager][ErrorView][404]", assigns)
    "Page not found - 404"
  end

  def render("500.html", assigns) do
    log_error("[Manager][ErrorView][500]", assigns)
    "Server internal error - 500"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(status, assigns) do
    log_error("[Manager][ErrorView][#{inspect status}]", assigns)
    render "500.html", assigns
  end

  defp log_error(prefix, assigns) do
    try do
      error_map = Map.from_struct(assigns[:reason])
      if error_map[:message] != nil do
        Logger.error("#{prefix} #{assigns[:reason].message}")
      else
        Logger.error("#{prefix} #{inspect assigns[:reason]}")
      end
    catch
      :exit, code   -> Logger.error("#{prefix} Exited with code #{inspect code}")
      :throw, value -> Logger.error("#{prefix} Throw called with #{inspect value}")
      what, value   -> Logger.error("#{prefix} Caught #{inspect what} with #{inspect value}")
    end        
  end
end
