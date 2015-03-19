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
  alias ProjectOmeletteManager.DB.Models.EtcdCluster

  alias ProjectOmeletteManager.Controllers.FormatHelper
  
  import Ecto.Query

  # TODO: Add authentication

  plug :action

  @moduledoc """
  This module contains the controllers for managing MessagingExchanges
  """  

  @sendable_exchange_fields [:id, :name, :inserted_at, :updated_at]
  @updatable_exchange_fields ["name"]

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
          Repo.delete(exchange)
        end)
        resp(conn, :no_content, "")
    end
  end
end