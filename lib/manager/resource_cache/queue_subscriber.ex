require Logger

defmodule OpenAperture.Manager.ResourceCache.QueueSubscriber do
  use GenServer

  alias OpenAperture.Manager.ResourceCache.CachedResource

  @logprefix "[ResourceCache.QueueSubscriber]"

  @spec start_link() :: GenServer.on_start
  def start_link() do
    if Application.get_env(OpenAperture.Manager, :cache_queue_monitor_autostart, true) do
      Logger.debug("#{@logprefix} Starting...")
        case GenServer.start_link(__MODULE__, :ok, name: __MODULE__) do
        {:ok, pid} ->
          Logger.debug("#{@logprefix} Startup Complete")
          {:ok, pid}
        {:error, reason} -> {:error, reason}
      end
    else
      Logger.debug("#{@logprefix} skipping startup: autostart disabled")
      Agent.start_link(fn -> nil end) #to return {:ok, pid} to the supervisor
    end
  end

  @spec init(:ok) :: {:ok, nil}
  def init(:ok) do
    OpenAperture.Manager.Messaging.ManagerQueue.build_and_subscribe("cache", &clear_cache/1)
    {:ok, nil}
  end

  @spec clear_cache(term) :: :ok | {:error, term}
  def clear_cache(%{type: type, key: key}), do: CachedResource.clear_local(type, key)
end