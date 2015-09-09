#
# == connection_options_resolver.ex
#
# This module contains the logic to resolve the appropriate connection options for a messaging client
#
require Logger

defmodule OpenAperture.Manager.Messaging.ConnectionOptionsResolver do
  use GenServer
  use Ecto.Model

  @moduledoc """
  This module contains the logic to resolve the appropriate connection options for a messaging client
  """

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingBroker


  @doc """
  Specific start_link implementation (required by the supervisor)

  ## Options

  ## Return Values

  {:ok, pid} | {:error, reason}
  """
  @spec start_link() :: {:ok, pid} | {:error, String.t}
  def start_link do
    GenServer.start_link(__MODULE__, %{exchanges: %{}, broker_connection_options: %{}, brokers: %{}}, name: __MODULE__)
  end

  @doc """
  Method to retrieve the appropriate connection options for a messaging client

  ## Options

  The `src_broker_id` option defines the source broker identifier (where is the message going to start)

  The `src_exchange_id` option defines the source exchange identifier (where is the message going to start)

  The `dest_exchange_id` option defines the destination exchange identifier (where is the message going to end)

  ## Return Values

  Returns the connection_option
  """
  @spec resolve(String.t, String.t, String.t) :: term
  def resolve(src_broker_id, src_exchange_id, dest_exchange_id) do
    GenServer.call(__MODULE__, {:resolve, src_broker_id, src_exchange_id, dest_exchange_id})
  end

  @doc """
  Method to retrieve the appropriate connection option for a messaging client to a specific broker

  ## Options

  The `src_broker_id` option defines the source broker identifier (where is the message going to start)

  ## Return Values

  Returns the connection_option
  """
  @spec get_for_broker(String.t) :: term
  def get_for_broker(broker_id) do
    GenServer.call(__MODULE__, {:get_for_broker, broker_id})
  end

  @doc """
  Call handler to resolve the connection options

  ## Options

  The `broker_id` option defines the source broker identifier (where is the message going to start)

  The `_from` option defines the tuple {from, ref}

  The `state` option represents the server's current state

  ## Return Values

  {:reply, OpenAperture.Messaging.ConnectionOptions.t, resolved_state}
  """
  @spec handle_call({:get_for_broker, String.t}, term, map) :: {:reply, OpenAperture.Messaging.ConnectionOptions.t, map}
  def handle_call({:get_for_broker, broker_id}, _from, state) do
    {connection_option, resolved_state} = get_connection_option_for_broker(state, broker_id)

    {:reply, connection_options_from_model(connection_option), resolved_state}
  end

  @doc """
  Call handler to resolve the connection options

  ## Options

  The `src_broker_id` option defines the source broker identifier (where is the message going to start)

  The `src_exchange_id` option defines the source exchange identifier (where is the message going to start)

  The `dest_exchange_id` option defines the destination exchange identifier (where is the message going to end)

  The `_from` option defines the tuple {from, ref}

  The `state` option represents the server's current state

  ## Return Values

      {:reply, OpenAperture.Messaging.ConnectionOptions, resolved_state}
  """
  @spec handle_call({:resolve, String.t, String.t, String.t}, term, map) :: {:reply, OpenAperture.Messaging.ConnectionOptions.t, map}
  def handle_call({:resolve, src_broker_id, src_exchange_id, dest_exchange_id}, _from, state) do
    #is src exchange restricted?
    {src_exchange_restrictions, resolved_state} = get_restrictions_for_exchange(state, src_exchange_id)

    #is dest exchange restricted?
    {dest_exchange_restrictions, resolved_state} = get_restrictions_for_exchange(resolved_state, dest_exchange_id)

    {connection_option, resolved_state} = cond do
      #if the dest is restricted, we have to use the dest broker options
      length(dest_exchange_restrictions) > 0 ->
        get_connection_option_for_brokers(resolved_state, dest_exchange_restrictions)

      #if the src is restricted, we have to use the dest broker options (don't know if src can connect to dest)
      length(src_exchange_restrictions) > 0 ->
        if length(dest_exchange_restrictions) == 0 do
          Logger.warn("[ConnectionOptionsResolver] The source exchange #{src_exchange_id} has restrictions, but no restrictions on destination exchange #{dest_exchange_id} were found.  Attempting to use source restrictions (but this may not work)...")
          get_connection_option_for_brokers(resolved_state, src_exchange_restrictions)
        else
          get_connection_option_for_brokers(resolved_state, dest_exchange_restrictions)
        end

      #nothing is restricted, use broker associated to the source exchange
      true ->
        get_connection_option_for_broker(resolved_state, src_broker_id)
    end

    {:reply, connection_options_from_model(connection_option), resolved_state}
  end

  defp connection_options_from_model(nil), do: nil
  defp connection_options_from_model(connection_option) do
    %OpenAperture.Messaging.AMQP.ConnectionOptions{
      id: connection_option.id,
      username: connection_option.username,
      password: connection_option.password,
      host: connection_option.host,
      port: connection_option.port,
      virtual_host: connection_option.virtual_host,
      heartbeat: 60
    }
    |> IO.inspect
  end

  @doc """
  Method to determine if the cached options are stale (i.e. retrieved > 5 minutes prior)

  ## Return Values

  Boolean
  """
  @spec cache_stale?(map | nil) :: term
  def cache_stale?(cache) do
    if cache == nil || cache[:retrieval_time] == nil do
      true
    else
      seconds = :calendar.datetime_to_gregorian_seconds(cache[:retrieval_time])
      now_seconds = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time)
      (now_seconds - seconds) > 300
    end
  end

  @doc """
  Method to identify a single connection option for a set of brokers

  ## Options

  The `state` option represents the server state

  The `exchange_id` option represents an MessageExchange identifier

  ## Return Values

  {Map, state}
  """
  @spec get_connection_option_for_brokers(map, list) :: {term, map}
  def get_connection_option_for_brokers(state, brokers) do
    idx = :random.uniform(length(brokers))-1
    {broker, _cur_idx} = Enum.reduce brokers, {nil, 0}, fn (cur_broker, {broker, cur_idx}) ->
      if cur_idx == idx do
        {cur_broker, cur_idx+1}
      else
        {broker, cur_idx+1}
      end
    end

    get_connection_option_for_broker(state, broker.id)
  end

  @doc """
  Method to select a connection option from a list of available options

  ## Options

  The `state` option represents the server state

  The `broker_id` option represents an MessageBroker identifier

  ## Return Values

  {Map, state}
  """
  @spec get_connection_option_for_broker(map, String.t) :: {term, map}
  def get_connection_option_for_broker(state, broker_id) do
    {connection_options, resolved_state} = case get_connection_options_from_cache(state, broker_id) do
      nil ->
        Logger.debug("[ConnectionOptionsResolver] Retrieving connection options for broker #{broker_id}...")
        connection_options = broker_connections(broker_id)
        if connection_options == nil do
          Logger.error("[ConnectionOptionsResolver] No connection options have been defined for broker #{broker_id}!")
        else
          Logger.debug("[ConnectionOptionsResolver] There are #{length(connection_options)} connection options defined for broker #{broker_id}")
        end
        {connection_options, cache_connection_options(state, broker_id, connection_options)}
      connection_options -> {connection_options, state}
    end
    connection_option = resolve_connection_option_for_broker(connection_options)

    {failover_connection_option, resolved_state} = case get_broker(resolved_state, broker_id) do
      {nil, resolved_state} ->
        Logger.error("[ConnectionOptionsResolver] Failed to retrieve broker #{broker_id}!")
        {nil, resolved_state}
      {broker, resolved_state} ->
        if broker.failover_broker_id != nil do
          case get_connection_options_from_cache(resolved_state, broker.failover_broker_id) do
            nil ->
              failover_connection_options = broker_connections(broker.failover_broker_id)
              {resolve_connection_option_for_broker(failover_connection_options), cache_connection_options(resolved_state, broker.failover_broker_id, failover_connection_options)}
            failover_connection_options -> {resolve_connection_option_for_broker(failover_connection_options), resolved_state}
          end
        else
          {nil, resolved_state}
        end
    end

    cond do
      connection_option == nil -> {nil, resolved_state}
      failover_connection_option == nil -> {connection_option, resolved_state}
      true ->
        {Map.merge(connection_option, %{
          "failover_id" => failover_connection_option.id,
          "failover_username" => failover_connection_option.username,
          "failover_password" => failover_connection_option.password,
          "failover_host" => failover_connection_option.host,
          "failover_port" => failover_connection_option.port,
          "failover_virtual_host" => failover_connection_option.virtual_host
        }), resolved_state}
    end
  end

  defp broker_connections(broker_id) do
    Repo.get(MessagingBroker, broker_id)
    |> assoc(:messaging_broker_connection)
    |> Repo.all
  end

  @doc """
  Method to check the cache for existing connection options

  ## Options

  The `broker_id` option represents an MessageBroker identifier

  ## Return Values

  Map
  """
  @spec get_connection_options_from_cache(map, String.t) :: list | nil
  def get_connection_options_from_cache(state, broker_id) do
    broker_id_cache = state[:broker_connection_options][broker_id]
    if cache_stale?(broker_id_cache) do
      Logger.debug("[ConnectionOptionsResolver] Connection options for broker #{broker_id} are not cached")
      nil
    else
      Logger.debug("[ConnectionOptionsResolver] Connection options for broker #{broker_id} are cached")
      broker_id_cache[:connection_options]
    end
  end

  @doc """
  Method to cache connection options

  ## Options

  The `broker_id` option represents an MessageBroker identifier

  The `connection_options` option represents the options to cache

  ## Return Values

  updated state
  """
  @spec cache_connection_options(map, String.t, Keyword.t) :: map
  def cache_connection_options(state, broker_id, connection_options) do
    broker_id_cache = %{
      retrieval_time: :calendar.universal_time,
      connection_options: connection_options
    }

    broker_cache = Map.put(state[:broker_connection_options], broker_id, broker_id_cache)
    Map.put(state, :broker_connection_options, broker_cache)
  end

  @doc """
  Method to retrieve a broker from cache or from the Manager

  ## Options

  The `state` option represents the current server state

  The `broker_id` option represents an MessagingBroker identifier

  ## Return Values

  Map of the MessagingBroker
  """
  @spec get_broker(map, String.t) :: {map | nil, map}
  def get_broker(state, broker_id) do
    broker_cache = state[:brokers][broker_id]
    if cache_stale?(broker_cache) do
      Logger.debug("[ConnectionOptionsResolver] Broker #{broker_id} is not cached, retrieving...")
      case Repo.get(MessagingBroker, broker_id) do
        nil ->
          Logger.error("[ConnectionOptionsResolver] Failed to retrieve broker #{broker_id}!")
          {nil, state}
        broker ->
          broker_cache = %{
            retrieval_time: :calendar.universal_time,
            broker: broker
          }

          broker_cache = Map.put(state[:brokers], broker_id, broker_cache)
          state = Map.put(state, :brokers, broker_cache)
          {broker, state}
      end
    else
      {broker_cache[:broker], state}
    end
  end

  @doc """
  Method to select a connection option from a list of available options

  ## Options

  The `exchange_id` option represents an MessageExchange identifier

  ## Return Values

  Map
  """
  @spec resolve_connection_option_for_broker([term]) :: term | nil
  def resolve_connection_option_for_broker(connection_options) do
    if connection_options != nil && length(connection_options) > 0 do
      idx = :random.uniform(length(connection_options))-1
      {connection_option, _cur_idx} = Enum.reduce connection_options, {nil, 0}, fn (cur_connection_option, {connection_option, cur_idx}) ->
        if cur_idx == idx do
          {cur_connection_option, cur_idx+1}
        else
          {connection_option, cur_idx+1}
        end
      end
      connection_option
    else
      nil
    end
  end

  @doc """
  Method to retrieve any broker restrictions for a specific exchange identifier

  ## Options

  The `state` option represents the server state

  The `exchange_id` option represents an MessageExchange identifier

  ## Return Values

  {List of broker Maps, state}
  """
  @spec get_restrictions_for_exchange(map, String.t) :: {list, map}
  def get_restrictions_for_exchange(state, exchange_id) do
    exchange_id_cache = state[:exchanges][exchange_id]
    unless cache_stale?(exchange_id_cache) do
      {exchange_id_cache[:broker_restrictions], state}
    else
      if exchange_id_cache == nil do
        exchange_id_cache = %{}
      end
      exchange_id_cache = Map.put(exchange_id_cache, :retrieval_time, :calendar.universal_time)

      #Find any restrictions
      restrictions = Repo.get(MessagingExchange, exchange_id)
      |> assoc(:messaging_exchange_brokers)
      |> Repo.all

      exchange_id_cache = Map.put(exchange_id_cache, :broker_restrictions, restrictions)
      exchange_cache = Map.put(state[:exchanges], exchange_id, exchange_id_cache)
      state = Map.put(state, :exchanges, exchange_cache)

      {restrictions, state}
    end
  end
end
