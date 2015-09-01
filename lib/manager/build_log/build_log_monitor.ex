require Logger

defmodule OpenAperture.Manager.BuildLogMonitor do
	use GenServer

  @spec start_link() :: GenServer.on_start
	def start_link() do
    if Application.get_env(OpenAperture.Manager, :build_log_monitor_autostart, true) do
      Logger.debug("[BuildLogMonitor] Starting...")
        case GenServer.start_link(__MODULE__, :ok, name: __MODULE__) do
	      {:ok, pid} ->
	        Logger.debug("[BuildLogMonitor] Startup Complete")
	        {:ok, pid}
	      {:error, reason} -> {:error, reason}
	    end
    else
      Logger.debug("[BuildLogMonitor] skipping startup: autostart disabled")
      Agent.start_link(fn -> nil end) #to return {:ok, pid} to the supervisor
    end
	end

  @spec init(:ok) :: {:ok, nil}
  def init(:ok) do
    OpenAperture.Manager.Messaging.ManagerQueue.build_and_subscribe("build_logs", &handle_logs/1)
    {:ok, nil}
  end

  @spec handle_logs(term) :: :ok | {:error, term}
  def handle_logs(payload) do
    Logger.debug("Broadcasting build logs for id: #{payload.workflow_id} #{inspect payload.logs}")
    OpenAperture.Manager.Endpoint.broadcast!("build_log:" <> payload.workflow_id, "build_log", %{logs: payload.logs})
  end
end
