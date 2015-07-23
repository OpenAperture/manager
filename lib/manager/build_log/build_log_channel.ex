require Logger

defmodule OpenAperture.Manager.BuildLogChannel do
  use Phoenix.Channel

  def join("build_log:" <> workflow_id, auth_msg, socket) do
    Logger.debug("[BuildLogChannel] join for workflow: #{workflow_id}, auth_msg: #{inspect auth_msg}")
    {:ok, socket}
  end


end