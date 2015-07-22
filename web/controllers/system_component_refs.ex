require Logger

defmodule OpenAperture.Manager.Controllers.SystemComponentRefs do
  use OpenAperture.Manager.Web, :controller

  require Repo
  import Ecto.Query

  alias OpenAperture.Manager.DB.Models.SystemComponentRef
  
  plug :action

  @moduledoc """
  This module contains the controller for managing SystemComponentRefs
  """  

  @sendable_fields [
    :id, 
		:type, 
		:source_repo, 
		:source_repo_git_ref, 
		:auto_upgrade_enabled,
    :inserted_at, 
    :updated_at
  ]

  @updatable_fields [
    "type", 
    "source_repo", 
    "source_repo_git_ref", 
    "auto_upgrade_enabled"
  ]

  @doc """
  GET /system_component_refs - Retrieve all SystemComponentRefs

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t
  def index(conn, _params) do
    ok(conn, Repo.all(SystemComponentRef), @sendable_fields)
 end  

  @doc """
  GET /system_component_refs/:type - Retrieve a SystemComponentRef

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t
  def show(conn, %{"type" => type}) do
    query = from scr in SystemComponentRef,
      where: scr.type == ^type,
      select: scr
    case Repo.all(query) do
      [] -> not_found(conn, "SystemComponentRef #{inspect type}")
      raw_components -> ok(conn, List.first(raw_components), @sendable_fields)
    end
  end

  @doc """
  POST /system_component_refs - Create a SystemComponentRef

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t
  def create(conn, params) do
  	type = params["type"]
  	if type == nil || String.length(type) == 0 do
  		bad_request(conn, "SystemComponentRef", [{:type, "type is required"}])
  	else
	    query = from scr in SystemComponentRef,
	      where: scr.type == ^type,
	      select: scr
	    case Repo.all(query) do
	      [] ->
	        changeset = SystemComponentRef.new(%{
	          "type" => type,
	          "source_repo" => params["source_repo"],
	          "source_repo_git_ref" => params["source_repo_git_ref"],
	          "auto_upgrade_enabled" => params["auto_upgrade_enabled"]
	        })
	        if changeset.valid? do
	          try do
	            component = Repo.insert!(changeset)
	            path = OpenAperture.Manager.Router.Helpers.system_component_refs_path(Endpoint, :show, component.type)

	            # Set location header
	            created(conn, path)
	          rescue
	            e -> internal_server_error(conn, "SystemComponentRef #{inspect type}", e ) 
	          end
	        else
	          bad_request(conn, "SystemComponentRef #{inspect type}", changeset.errors)
	        end
	      _ -> conflict(conn, "SystemComponentRef #{inspect type}")
	    end
  	end
  end

  @doc """
  PUT /system_component_refs/:type - Update a SystemComponentRef

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t
  def update(conn, params) do
  	type = params["type"]
		if type == nil || String.length(type) == 0 do
  		bad_request(conn, "SystemComponentRef", [{:type, "type is required"}])
  	else  	
	    query = from scr in SystemComponentRef,
	      where: scr.type == ^type,
	      select: scr
	    case Repo.all(query) do
	      [] -> not_found(conn, "SystemComponentRef #{inspect type}")
	      components -> 
	        changeset = SystemComponentRef.new(%{
	          "type" => type,
	          "source_repo" => params["source_repo"],
	          "source_repo_git_ref" => params["source_repo_git_ref"],
	          "auto_upgrade_enabled" => params["auto_upgrade_enabled"]
	        })

	        if changeset.valid? do
	          try do
	          	changeset = SystemComponentRef.update(List.first(components), Map.take(params, @updatable_fields))
	            Repo.update!(changeset)
	            path = OpenAperture.Manager.Router.Helpers.system_component_refs_path(Endpoint, :show, type)

	            # Set location header
	            no_content(conn, path)
	          rescue
	            e -> internal_server_error(conn, "SystemComponentRef", e)
	          end
	        else
	        	bad_request(conn, "SystemComponentRef #{inspect type}", changeset.errors)
	        end
	    end
	  end
  end  

  @doc """
  DELETE /system_component_refs/:type - Delete a SystemComponentRef

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t
  def destroy(conn, %{"type" => type} = _params) do
    query = from scr in SystemComponentRef,
      where: scr.type == ^type,
      select: scr
    case Repo.all(query) do
      [] -> not_found(conn, "SystemComponentRef #{inspect type}")
      components -> 
        Repo.transaction(fn ->
          Repo.delete!(List.first(components))
        end)
        no_content(conn)
    end
  end  
end