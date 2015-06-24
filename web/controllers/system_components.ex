require Logger

defmodule OpenAperture.Manager.Controllers.SystemComponents do
  use OpenAperture.Manager.Web, :controller

  require Repo
  import Ecto.Query

  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Manager.DB.Models.MessagingExchange
  
  plug :action

  @moduledoc """
  This module contains the controller for managing SystemComponents
  """  

  @sendable_fields [
    :id, 
    :messaging_exchange_id,
		:type, 
		:source_repo, 
		:source_repo_git_ref, 
		:deployment_repo,
    :deployment_repo_git_ref,
    :upgrade_strategy,
    :inserted_at, 
    :updated_at
  ]

  @updatable_fields [
    "messaging_exchange_id",
    "type", 
    "source_repo", 
    "source_repo_git_ref", 
    "deployment_repo",
    "deployment_repo_git_ref",
    "upgrade_strategy"
  ]

  @doc """
  GET /system_components - Retrieve all SystemComponents

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t
  def index(conn, _params) do
    ok(conn, Repo.all(SystemComponent), @sendable_fields)
 end  

  @doc """
  GET /system_components/:id - Retrieve a SystemComponent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t
  def show(conn, params) do
    case Repo.get(SystemComponent, params["id"]) do
      nil -> not_found(conn, "SystemComponent #{params["id"]}")
      component -> ok(conn, component, @sendable_fields)
    end
  end

  @doc """
  POST /system_components - Create a SystemComponent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t
  def create(conn, params) do
    changeset = SystemComponent.new(%{
      messaging_exchange_id: params["messaging_exchange_id"],
      type: params["type"],
      source_repo: params["source_repo"],
      source_repo_git_ref: params["source_repo_git_ref"],
      deployment_repo: params["deployment_repo"],
      deployment_repo_git_ref: params["deployment_repo_git_ref"],      
      upgrade_strategy: params["upgrade_strategy"]
    })
    if changeset.valid? do
      try do
        query = from sc in SystemComponent,
          where: sc.type == ^params["type"] and sc.messaging_exchange_id == ^params["messaging_exchange_id"],
          select: sc
        case Repo.all(query) do
          [] -> 
            component = Repo.insert(changeset)
            path = OpenAperture.Manager.Router.Helpers.system_components_path(Endpoint, :show, component.id)

            # Set location header
            created(conn, path)            
          _ -> conflict(conn, "SystemComponent #{inspect params["type"]}")
        end
      rescue
        e -> internal_server_error(conn, "SystemComponent", e ) 
      end
    else
      bad_request(conn, "SystemComponent", changeset.errors)
    end
  end

  @doc """
  PUT /system_components/:id - Update a SystemComponent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t
  def update(conn, params) do
    case Repo.get(SystemComponent, params["id"]) do
      nil -> not_found(conn, "SystemComponent #{params["id"]}")
      component ->
        changeset = SystemComponent.new(%{
          messaging_exchange_id: params["messaging_exchange_id"],
          type: params["type"],
          source_repo: params["source_repo"],
          source_repo_git_ref: params["source_repo_git_ref"],
          deployment_repo: params["deployment_repo"],
          deployment_repo_git_ref: params["deployment_repo_git_ref"],      
          upgrade_strategy: params["upgrade_strategy"]
        })

        if changeset.valid? do
          try do
            original_exchange = Repo.get(MessagingExchange, component.messaging_exchange_id)
            new_exchange = Repo.get(MessagingExchange, params["messaging_exchange_id"])

            #the component needs to be reviewed to ensure it's not violating any constraints
            conflict = if params["type"] != component.type || new_exchange.id != original_exchange.id do
              query = from sc in SystemComponent,
                where: sc.type == ^params["type"] and sc.messaging_exchange_id == ^params["messaging_exchange_id"],
                select: sc
              case Repo.all(query) do
                [] -> false
                _ -> true
              end
            else
              false
            end

            if conflict do
              conflict(conn, "SystemComponent #{inspect params["type"]}")
            else
            	changeset = SystemComponent.update(component, Map.take(params, @updatable_fields))
              Repo.update(changeset)
              path = OpenAperture.Manager.Router.Helpers.system_components_path(Endpoint, :show, component.id)

              # Set location header
              no_content(conn, path)
            end
          rescue
            e -> internal_server_error(conn, "SystemComponent", e)
          end
        else
        	bad_request(conn, "SystemComponent #{params["id"]}", changeset.errors)
        end
	  end
  end  

  @doc """
  DELETE /system_components/:id - Delete a SystemComponent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t
  def destroy(conn, params) do
    case Repo.get(SystemComponent, params["id"]) do
      nil -> not_found(conn, "SystemComponent #{params["id"]}")
      component ->
        Repo.transaction(fn ->
          Repo.delete(component)
        end)
        no_content(conn)
    end
  end  
end