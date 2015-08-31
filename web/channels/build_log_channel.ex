require Logger
defmodule OpenAperture.Manager.Channels.BuildLogChannel do
  use Phoenix.Channel

  def join("build_log:" <> workflow_id, _auth_msg, socket) do
    Logger.debug("[BuildLogChannel] join for workflow: #{workflow_id}")
    {:ok, socket}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast! socket, "new_msg", %{body: body}
    {:noreply, socket}
  end

  def handle_out("new_msg", payload, socket) do
    push socket, "new_msg", payload
    {:noreply, socket}
  end  
end