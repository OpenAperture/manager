defmodule OpenAperture.Manager.ResourceCache.Registry do
  use GenServer
  @connection_options nil
  use OpenAperture.Messaging

  alias OpenAperture.Manager.ResourceCache.CachedResource

  @con_cache_ttl [ttl_check: :timer.seconds(60*5), ttl: :timer.seconds(60*60)]

  @spec start_link :: GenServer.on_start
  def start_link, do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec init(:ok) :: {:ok, []}
  def init(:ok) do
    IO.puts "Registry starting up"
    __MODULE__.start_queue CachedResource.cache_disabled
    {:ok, []}
  end

  @spec start_queue(boolean) :: term
  def start_queue(false), do: OpenAperture.Manager.Messaging.ManagerQueue.build_and_subscribe("cache", &clear_cache/1)
  def start_queue(true), do: Logger.debug("[ResourceCache.Registry] skipping startup: autostart disabled")

  @spec verify_started(atom) :: atom
  def verify_started(type), do: GenServer.call(__MODULE__, {:verify_started, type})

  @spec get_all_active_cache_types :: [atom]
  def get_all_active_cache_types, do: GenServer.call(__MODULE__, :get_all_cache_types)

  @spec clear_cache(map) :: term
  defp clear_cache(payload) do
    Logger.info("[ResourceCache.Registry] Clear received for #{payload[:type]}, #{payload[:key]}")
    ConCache.delete(payload[:type], payload[:key])
  end

  @spec handle_call(:get_all_cache_types | {:verify_started, atom}, pid, [atom]) :: {:reply, [atom] | atom, [atom]}
  def handle_call(:get_all_cache_types, _from, state), do: {:reply, state, state}
  def handle_call({:verify_started, type}, _from, state), do: {:reply, type, start_and_add(!(type in state), type, state)}

  @spec start_and_add(boolean, atom, [atom]) :: [atom]
  def start_and_add(false, _type, state), do: state
  def start_and_add(true, type, state) do
    ConCache.start_link(@con_cache_ttl, [name: type])
    state ++ [type]
  end
end