#
# == connection_pools.ex
#
# This module contains the controllers for managing MessagingExchanges
#
require Logger

defmodule OpenAperture.Manager.Controllers.MessagingExchanges do
  use OpenAperture.Manager.Web, :controller

  require Repo

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  alias OpenAperture.Manager.DB.Models.MessagingExchangeModule
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.SystemComponent

  alias OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  alias OpenAperture.Manager.Util
  
  import Ecto.Query

  # TODO: Add authentication

  plug :action

  @moduledoc """
  This module contains the controllers for managing MessagingExchanges
  """  

  @sendable_exchange_fields [
    :id, 
    :name, 
    :failover_exchange_id, 
    :parent_exchange_id, 
    :routing_key_fragment, 
    :routing_key, #dynamic
    :root_exchange_name, #dynamic
    :inserted_at, 
    :updated_at
  ]
  @updatable_exchange_fields [
    "name", 
    "failover_exchange_id", 
    "parent_exchange_id", 
    "routing_key_fragment"
  ]

  @sendable_exchange_broker_fields [
    :id, 
    :messaging_exchange_id, 
    :messaging_broker_id, 
    :inserted_at, 
    :updated_at
  ]

  @sendable_system_component_fields [
    :id, 
    :messaging_exchange_id,
    :type, 
    :source_repo, 
    :source_repo_git_ref, 
    :deployment_repo,
    :deployment_repo_git_ref,
    :upgrade_strategy,
    :inserted_at, 
    :updated_at,
    :status,
    :upgrade_status
  ]  

  @doc """
  GET /messaging/exchanges - Retrieve all MessagingExchanges

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(term, [any]) :: term
  def index(conn, _params) do
    exchanges = 
      Repo.all(MessagingExchange)
      |> FormatHelper.to_sendable(@sendable_exchange_fields)

    json conn, resolve_hierachy(exchanges, [])
  end

  @doc """
  GET /messaging/exchanges/:id - Retrieve a MessagingExchange

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show(term, [any]) :: term
  def show(conn, %{"id" => id}) do
    case Repo.get(MessagingExchange, id) do
      nil -> 
        conn 
        |> put_status(:not_found) 
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingExchange")   
      raw_exchange -> 
        exchange = 
          raw_exchange
          |> FormatHelper.to_sendable(@sendable_exchange_fields) 

        json conn, List.first(resolve_hierachy([exchange], []))
    end
  end

  def resolve_hierachy([], updated_exchanges) do
    updated_exchanges
  end

  def resolve_hierachy([exchange | remaining_exchanges], updated_exchanges) do
    {routing_key, root_exchange} = Util.build_route_hierarchy(exchange[:id], nil, nil)
    exchange = Map.put(exchange, :routing_key, to_string(routing_key))
    exchange = Map.put(exchange, :root_exchange_name, root_exchange.name)

    resolve_hierachy(remaining_exchanges, updated_exchanges ++ [exchange])
  end

  @doc """
  POST /messaging/exchanges - Create a MessagingExchange

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(term, [any]) :: term
  def create(conn, %{"name" => name} = params) when name != "" do
    query = from b in MessagingExchange,
      where: b.name == ^name,
      select: b
    case Repo.all(query) do
      [] ->
        changeset = MessagingExchange.new(%{
          "name" => name,
          "failover_exchange_id" => params["failover_exchange_id"],
          "parent_exchange_id" => params["parent_exchange_id"],
          "routing_key_fragment" => params["routing_key_fragment"]
        })
        if changeset.valid? do
          try do
            exchange = Repo.insert(changeset)
            path = OpenAperture.Manager.Router.Helpers.messaging_exchanges_path(Endpoint, :show, exchange.id)

            # Set location header
            conn
            |> put_resp_header("location", path)
            |> resp(:created, "")
          rescue
            e ->
              Logger.error("Error inserting exchange record for #{name}: #{inspect e}")
              conn 
              |> put_status(:internal_server_error) 
              |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingExchange")  
          end
        else
          conn 
          |> put_status(:bad_request) 
          |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingExchange")  
        end
      _ ->
        conn 
        |> put_status(:conflict) 
        |> json ResponseBodyFormatter.error_body(:conflict, "MessagingExchange")  
    end
  end

  # This action only matches if a param is missing
  def create(conn, _params) do
    conn 
    |> put_status(:bad_request) 
    |> json ResponseBodyFormatter.error_body(:bad_request, "MessagingExchange")  
  end

  @doc """
  PUT/PATCH /messaging/exchanges/:id - Update a MessagingExchange

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec update(term, [any]) :: term
  def update(conn, %{"id" => id} = params) do
    exchange = Repo.get(MessagingExchange, id)

    if exchange == nil do
      conn 
      |> put_status(:not_found) 
      |> json ResponseBodyFormatter.error_body(:not_found, "MessagingExchange")  
    else     
      changeset = MessagingExchange.new(%{"name" => 
        params["name"]
      })
      if !changeset.valid? do
        conn 
        |> put_status(:bad_request) 
        |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingExchange")        
      else
        # Check to see if there is another exchange with the same name
        query = from b in MessagingExchange,
          where: b.name == ^params["name"],
          select: b

        conflict = case Repo.all(query) do
          [] -> false
          exchanges -> List.first(exchanges).id != exchange.id
        end
           
        if conflict do
          conn 
          |> put_status(:conflict) 
          |> json ResponseBodyFormatter.error_body(:conflict, "MessagingExchange")  
        else
          changeset = MessagingExchange.update(exchange, Map.take(params, @updatable_exchange_fields))
          if changeset.valid? do
            try do
              Repo.update(changeset)
              path = OpenAperture.Manager.Router.Helpers.messaging_exchanges_path(Endpoint, :show, id)
              conn
              |> put_resp_header("location", path)
              |> resp(:no_content, "")
            rescue
              e ->
                Logger.error("Error inserting exchange record for #{params["name"]}: #{inspect e}")
                conn 
                |> put_status(:internal_server_error) 
                |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingExchange")  
            end          
          else
            conn 
            |> put_status(:bad_request) 
            |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingExchange")            
          end
        end
      end
    end
  end

  # This action only matches if a param is missing
  def update(conn, _params) do
    conn 
    |> put_status(:bad_request) 
    |> json ResponseBodyFormatter.error_body(:bad_request, "MessagingExchange")  
  end

  @doc """
  DELETE /messaging/exchanges/:id - Delete a MessagingExchange

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy(term, [any]) :: term
  def destroy(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingExchange, id) do
      nil -> 
        conn 
        |> put_status(:not_found) 
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingExchange")  
      exchange ->
        Repo.transaction(fn ->
          Repo.update_all(from(e in EtcdCluster, where: e.messaging_exchange_id  == ^id), messaging_exchange_id: nil)
          Repo.update_all(from(e in MessagingExchange, where: e.failover_exchange_id  == ^id), failover_exchange_id: nil)
          Repo.update_all(from(e in MessagingExchange, where: e.parent_exchange_id == ^id), parent_exchange_id: nil)
          Repo.delete_all(from(b in MessagingExchangeBroker, where: b.messaging_exchange_id  == ^id))
          Repo.delete_all(from(m in MessagingExchangeModule, where: m.messaging_exchange_id  == ^id))
          Repo.delete_all(from(sc in SystemComponent, where: sc.messaging_exchange_id  == ^id))
          Repo.delete(exchange)
        end)
        resp(conn, :no_content, "")
    end
  end

  @doc """
  POST /messaging/exchanges/:id/brokers - Create a MessagingExchangeBroker

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create_broker_restriction(term, [any]) :: term
  def create_broker_restriction(conn, %{"id" => id, "messaging_broker_id" => messaging_broker_id} = _params) when messaging_broker_id != "" do
    exchange = Repo.get(MessagingExchange, id)
    broker = Repo.get(MessagingBroker, messaging_broker_id)

    cond do
      exchange == nil -> 
        conn 
        |> put_status(:not_found) 
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingExchange")  
      broker == nil -> 
        conn 
        |> put_status(:bad_request) 
        |> json ResponseBodyFormatter.error_body(:bad_request, "MessagingBroker")  
      true ->
        query = from b in MessagingExchangeBroker,
          where: b.messaging_exchange_id == ^id and b.messaging_broker_id == ^messaging_broker_id,
          select: b
        case Repo.all(query) do
          [] ->
            changeset = MessagingExchangeBroker.new(%{"messaging_exchange_id" => id, "messaging_broker_id" => messaging_broker_id})
            if changeset.valid? do
              try do
                exchange = Repo.insert(changeset)
                path = OpenAperture.Manager.Router.Helpers.messaging_exchanges_path(Endpoint, :get_broker_restrictions, exchange.id)

                # Set location header
                conn
                |> put_resp_header("location", path)
                |> resp(:created, "")
              rescue
                e ->
                  Logger.error("Error inserting exchange record for exchange #{id}, broker #{messaging_broker_id}: #{inspect e}")
                  conn 
                  |> put_status(:internal_server_error) 
                  |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingExchange")  
              end
            else
              conn 
              |> put_status(:bad_request) 
              |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingExchange")  
            end
          _ ->
            conn |> resp(:conflict, "")
        end        
    end
  end

  # This action only matches if a param is missing
  def create_broker_restriction(conn, _params) do
    conn 
    |> put_status(:bad_request) 
    |> json ResponseBodyFormatter.error_body(:bad_request, "MessagingExchange")  
  end

  @doc """
  GET /messaging/exchanges/:id/brokers - Retrieve MessagingExchangeBrokers

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec get_broker_restrictions(term, [any]) :: term
  def get_broker_restrictions(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingExchange, id) do
      nil -> 
        conn 
        |> put_status(:not_found) 
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingExchange")  
      _exchange -> 
        query = from b in MessagingExchangeBroker,
          where: b.messaging_exchange_id == ^id,
          select: b
        exchange_brokers = Repo.all(query)
        cond do
          exchange_brokers == nil -> json conn, []
          exchange_brokers != nil && length(exchange_brokers) == 0 -> json conn, []
          true ->
            sendable_exchange_brokers = Enum.reduce exchange_brokers, [], fn (exchange_broker, sendable_exchange_brokers) ->
              sendable_exchange_brokers ++ [FormatHelper.to_sendable(exchange_broker, @sendable_exchange_broker_fields)]
            end
            json conn, sendable_exchange_brokers
        end
    end
  end

  @doc """
  DELETE /messaging/exchanges/:id/brokers - Delete MessagingExchangeBrokers

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy_broker_restrictions(term, [any]) :: term
  def destroy_broker_restrictions(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingExchange, id) do
      nil -> 
        conn 
        |> put_status(:not_found) 
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingExchange")  
      _exchange ->
        Repo.transaction(fn ->
          Repo.delete_all(from(b in MessagingExchangeBroker, where: b.messaging_exchange_id == ^id))
        end)
        resp(conn, :no_content, "")
    end
  end

  @doc """
  GET /messaging/exchanges/:id/clusters - Retrieve EtcdClusters which have an associated MessagingExchange

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show_clusters(term, [any]) :: term
  def show_clusters(conn, %{"id" => id} = params) do
    case Repo.get(MessagingExchange, id) do
      nil -> 
        conn 
        |> put_status(:not_found) 
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingExchange")  
      _exchange -> 
        if params["allow_docker_builds"] != nil do
          query = from c in EtcdCluster,
            where: c.messaging_exchange_id == ^id and c.allow_docker_builds == ^params["allow_docker_builds"],
            select: c
        else
          query = from c in EtcdCluster,
            where: c.messaging_exchange_id == ^id,
            select: c
        end

      case Repo.all(query) do
        nil -> json conn, []
        [] -> json conn, []
        clusters -> 
          sendable_clusters = Enum.reduce clusters, [], fn (cluster, sendable_clusters) ->
            sendable_clusters ++ [Map.from_struct(cluster)]
          end
          json conn, sendable_clusters
      end
    end
  end

  @doc """
  GET /messaging/exchanges/:id/system_components - Retrieve associated SystemComponents

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show_components(term, [any]) :: term
  def show_components(conn, %{"id" => id}) do
    case Repo.get(MessagingExchange, id) do
      nil -> not_found(conn, "MessagingExchange #{id}")
      _exchange -> 
        query = from sc in SystemComponent,
          where: sc.messaging_exchange_id == ^id,
          select: sc
        json conn, convert_raw_components(Repo.all(query))
    end
  end

  @doc false
  # Method to convert an array of DB.Models.SystemComponents into an array of List of SystemComponents
  #
  # Options
  #
  # The `raw_workflows` option defines the array of structs of the DB.Models.SystemComponents to be parsed
  #
  ## Return Values
  #
  # List of parsed SystemComponents
  #
  def convert_raw_components(raw_components) do
    case raw_components do
      nil -> []
      [] -> []
      _ ->
        Enum.reduce raw_components, [], fn(raw_component, components) -> 
          component = FormatHelper.to_sendable(raw_component, @sendable_system_component_fields)
          if (component != nil) do
            #stored as String in the db
            if (component[:upgrade_status] != nil) do
              component = Map.put(component, :upgrade_status, Poison.decode!(component[:upgrade_status]))
            end

            components = components ++ [component]
          end

          components
        end
    end
  end
end