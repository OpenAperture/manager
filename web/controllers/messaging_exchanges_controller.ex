#
# == connection_pools.ex
#
# This module contains the controllers for managing MessagingExchanges
#
require Logger

defmodule ProjectOmeletteManager.Web.Controllers.MessagingExchangesController do
  use ProjectOmeletteManager.Web, :controller

  require Repo

  alias ProjectOmeletteManager.Endpoint
  alias ProjectOmeletteManager.DB.Models.MessagingExchange
  alias ProjectOmeletteManager.DB.Models.MessagingBroker
  alias ProjectOmeletteManager.DB.Models.MessagingExchangeBroker
  alias ProjectOmeletteManager.DB.Models.EtcdCluster

  alias ProjectOmeletteManager.Controllers.FormatHelper
  
  import Ecto.Query

  # TODO: Add authentication

  plug :action

  @moduledoc """
  This module contains the controllers for managing MessagingExchanges
  """  

  @sendable_exchange_fields [:id, :name, :failover_exchange_id, :inserted_at, :updated_at]
  @updatable_exchange_fields ["name", "failover_exchange_id"]

  @sendable_exchange_broker_fields [:id, :messaging_exchange_id, :messaging_broker_id, :inserted_at, :updated_at]

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
    json conn, Repo.all(MessagingExchange)
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
      nil -> resp(conn, :not_found, "")
      exchange -> json conn, exchange |> FormatHelper.to_sendable(@sendable_exchange_fields)
    end
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
  def create(conn, %{"name" => name} = _params) when name != "" do
    query = from b in MessagingExchange,
      where: b.name == ^name,
      select: b
    case Repo.all(query) do
      [] ->
        changeset = MessagingExchange.new(%{"name" => name})
        if changeset.valid? do
          try do
            exchange = Repo.insert(changeset)
            path = ProjectOmeletteManager.Router.Helpers.messaging_exchanges_path(Endpoint, :show, exchange.id)

            # Set location header
            conn
            |> put_resp_header("location", path)
            |> resp(:created, "")
          rescue
            e ->
              Logger.error("Error inserting exchange record for #{name}: #{inspect e}")
              resp(conn, :internal_server_error, "")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json FormatHelper.keywords_to_map(changeset.errors)
        end
      _ ->
        conn |> resp(:conflict, "")
    end
  end

  # This action only matches if a param is missing
  def create(conn, _params) do
    Plug.Conn.resp(conn, :bad_request, "name is required")
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
      resp(conn, :not_found, "")
    else
      changeset = MessagingExchange.new(%{"name" => params["name"]})
      if changeset.valid? do
        # Check to see if there is another exchange with the same name
        query = from b in MessagingExchange,
          where: b.name == ^params["name"],
          select: b

        case Repo.all(query) do
          [] ->
            changeset = MessagingExchange.changeset(exchange, Map.take(params, @updatable_exchange_fields))

            try do
              Repo.update(changeset)
              path = ProjectOmeletteManager.Router.Helpers.messaging_exchanges_path(Endpoint, :show, id)
              conn
              |> put_resp_header("location", path)
              |> resp(:no_content, "")
            rescue
              e ->
                Logger.error("Error inserting exchange record for #{params["name"]}: #{inspect e}")
                resp(conn, :internal_server_error, "")
            end             
          _ ->
            resp(conn, :conflict, "")
        end
      else
        conn
        |> put_status(:bad_request)
        |> json FormatHelper.keywords_to_map(changeset.errors)
      end
    end
  end

  # This action only matches if a param is missing
  def update(conn, _params) do
    resp(conn, :bad_request, "name is required")
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
      nil -> resp(conn, :not_found, "")
      exchange ->
        Repo.transaction(fn ->
          Repo.update_all(from(e in EtcdCluster, where: e.messaging_exchange_id  == ^id), messaging_exchange_id: nil)
          Repo.update_all(from(e in MessagingExchange, where: e.failover_exchange_id  == ^id), failover_exchange_id: nil)
          Repo.delete_all(from(b in MessagingExchangeBroker, where: b.messaging_exchange_id  == ^id))          
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
      exchange == nil -> resp(conn, :not_found, "")
      broker == nil -> resp(conn, :bad_request, "a valid messaging_broker_id is required")
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
                path = ProjectOmeletteManager.Router.Helpers.messaging_exchanges_path(Endpoint, :get_broker_restrictions, exchange.id)

                # Set location header
                conn
                |> put_resp_header("location", path)
                |> resp(:created, "")
              rescue
                e ->
                  Logger.error("Error inserting exchange record for exchange #{id}, broker #{messaging_broker_id}: #{inspect e}")
                  resp(conn, :internal_server_error, "")
              end
            else
              conn
              |> put_status(:bad_request)
              |> json FormatHelper.keywords_to_map(changeset.errors)
            end
          _ ->
            conn |> resp(:conflict, "")
        end        
    end
  end

  # This action only matches if a param is missing
  def create_broker_restriction(conn, _params) do
    Plug.Conn.resp(conn, :bad_request, "messaging_broker_id is required")
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
      nil -> resp(conn, :not_found, "")
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
      nil -> resp(conn, :not_found, "")
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
      nil -> resp(conn, :not_found, "")
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
end