require Logger

defmodule OpenAperture.Manager.BuildLogChannel do
  use Phoenix.Channel

  def join("build_log:" <> workflow_id, _auth_msg, socket) do
    Logger.debug("[BuildLogChannel] join for workflow: #{workflow_id}")
    {:ok, socket}
  end

end