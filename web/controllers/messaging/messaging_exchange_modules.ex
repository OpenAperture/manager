#
# == messaging_exchange_modules.ex
#
# This module contains the controllers for managing MessagingExchangeModules
#
require Logger

defmodule OpenAperture.Manager.Controllers.MessagingExchangeModules do
  use OpenAperture.Manager.Web, :controller

  require Repo

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingExchangeModule, as: MessagingExchangeModuleDb

  alias OpenAperture.Manager.Controllers.FormatHelper
  
  import Ecto.Query, only: [from: 2]


  plug :action

  @moduledoc """
  This module contains the controllers for managing MessagingExchangeModules
  """  

  @sendable_fields [:id, :messaging_exchange_id, :hostname, :type, :status, :workload, :inserted_at, :updated_at]


  @doc """
  GET /messaging/exchanges/:id/modules - Retrieve all MessagingExchangeModules for an exchange

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(term, [any]) :: term
  def index(conn, %{"id" => id}) do
    case Repo.get(MessagingExchange, id) do
      nil -> resp(conn, :not_found, "")    
      _ ->
        query = 
          from m in MessagingExchangeModuleDb,
          where: m.messaging_exchange_id == ^id,
          select: m
        json conn, Repo.all(query) |> FormatHelper.to_sendable(@sendable_fields) |> FormatHelper.to_string_timestamps
    end
  end

  @doc """
  GET /messaging/exchanges/:id/modules/:hostname - Retrieve a MessagingExchangeModule

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show(term, [any]) :: term
  def show(conn, %{"id" => id, "hostname" => hostname}) do
    case Repo.get(MessagingExchange, id) do
      nil -> resp(conn, :not_found, "")    
      _ ->    
        query = from m in MessagingExchangeModuleDb,
          where: m.messaging_exchange_id == ^id and m.hostname == ^hostname,
          select: m
        case Repo.all(query) do
          [] -> resp(conn, :not_found, "")
          modules -> json conn, List.first(modules) |> FormatHelper.to_sendable(@sendable_fields) |> FormatHelper.to_string_timestamps
        end
    end
  end  

  @doc """
  POST /messaging/exchanges - Create a MessagingExchangeModule

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(term, [any]) :: term
  def create(conn, %{"id" => id} = params) do
    case Repo.get(MessagingExchange, id) do
      nil -> resp(conn, :not_found, "")    
      _ ->    
        changeset = MessagingExchangeModuleDb.new(%{
          "messaging_exchange_id" => id,
          "hostname" => params["hostname"],
          "type" => params["type"],
          "status" => params["status"],
          "workload" => params["workload"]
        })
        unless changeset.valid? do
          conn
          |> put_status(:bad_request)
          |> json inspect(changeset.errors)      
        else
          query = from m in MessagingExchangeModuleDb,
            where: m.messaging_exchange_id == ^id and m.hostname == ^params["hostname"],
            select: m
          case Repo.all(query) do
            [] ->
              Logger.debug("No records exist for hostname #{params["hostname"]}...")
            modules ->
              Logger.debug("Deleting a previous record for hostname #{params["hostname"]}...")
              Repo.transaction(fn ->
                Enum.reduce modules, nil, fn (module, _errors) ->
                  Repo.delete(module)
                end
              end)
          end

          try do
            module = Repo.insert(changeset)
            path = OpenAperture.Manager.Router.Helpers.messaging_exchange_modules_path(Endpoint, :show, id, module.hostname)

            # Set location header
            conn
            |> put_resp_header("location", path)
            |> resp(:created, "")
          rescue
            e ->
              Logger.error("Error inserting module record for #{params["hostname"]}: #{inspect e}")
              resp(conn, :internal_server_error, "")
          end
        end    
    end
  end

  @doc """
  DELETE /messaging/exchanges/:id/modules/:hostname - Delete a MessagingExchangeModule

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy(term, [any]) :: term
  def destroy(conn, %{"id" => id, "hostname" => hostname} = _params) do
    case Repo.get(MessagingExchange, id) do
      nil -> resp(conn, :not_found, "")    
      _ ->    
        query = from m in MessagingExchangeModuleDb,
          where: m.messaging_exchange_id == ^id and m.hostname == ^hostname,
          select: m    
        case Repo.all(query) do
          [] -> resp(conn, :not_found, "")
          modules ->
            Repo.transaction(fn ->
              Enum.reduce modules, nil, fn (module, _errors) ->
                Repo.delete(module)
              end
            end)
            resp(conn, :no_content, "")
        end
    end
  end  
end