require Logger

defmodule OpenAperture.Manager.Controllers.SystemComponents do
  use OpenAperture.Manager.Web, :controller

  require Repo
  import Ecto.Query

  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Manager.DB.Models.MessagingExchange

  alias OpenAperture.OverseerApi.Publisher, as: OverseerPublisher
  alias OpenAperture.OverseerApi.Request, as: OverseerRequest
  
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
    json conn, convert_raw_components(Repo.all(SystemComponent))
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
      component -> 
        json conn, List.first(convert_raw_components([component]))
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
    upgrade_status = if params["upgrade_status"] != nil do
      Poison.encode!(params["upgrade_status"])
    else
      nil
    end

    changeset = SystemComponent.new(%{
      messaging_exchange_id: params["messaging_exchange_id"],
      type: params["type"],
      source_repo: params["source_repo"],
      source_repo_git_ref: params["source_repo_git_ref"],
      deployment_repo: params["deployment_repo"],
      deployment_repo_git_ref: params["deployment_repo_git_ref"],      
      upgrade_strategy: params["upgrade_strategy"],
      status: params["status"],
      upgrade_status: upgrade_status
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
        upgrade_status = if params["upgrade_status"] != nil do
          Poison.encode!(params["upgrade_status"])
        else
          nil
        end

        changeset = SystemComponent.new(%{
          messaging_exchange_id: params["messaging_exchange_id"],
          type: params["type"],
          source_repo: params["source_repo"],
          source_repo_git_ref: params["source_repo_git_ref"],
          deployment_repo: params["deployment_repo"],
          deployment_repo_git_ref: params["deployment_repo_git_ref"],      
          upgrade_strategy: params["upgrade_strategy"],
          status: params["status"],
          upgrade_status: upgrade_status
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
              new_fields = Map.take(params, @updatable_fields)
              new_fields = Map.put(new_fields, "upgrade_status", upgrade_status)
            	changeset = SystemComponent.update(component, new_fields)
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

  @doc """
  POST /system_components/:id/upgrade - Request an upgrade of a SystemComponent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec upgrade(Plug.Conn.t, [any]) :: Plug.Conn.t
  def upgrade(conn, params) do
    case Repo.get(SystemComponent, params["id"]) do
      nil -> not_found(conn, "SystemComponent #{params["id"]}")
      component ->
        OverseerPublisher.publish_request(
          %OverseerRequest{action: :upgrade_request, options: %{component_type: component.type}},
          component.messaging_exchange_id
        )
        no_content(conn)
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
          component = FormatHelper.to_sendable(raw_component, @sendable_fields)
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