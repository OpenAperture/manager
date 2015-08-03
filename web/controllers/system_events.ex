require Logger

defmodule OpenAperture.Manager.Controllers.SystemEvents do
  use OpenAperture.Manager.Web, :controller

  require Repo

  alias OpenAperture.Manager.DB.Models.SystemEvent
  alias OpenAperture.Manager.DB.Queries.SystemEvent, as: SystemEventQuery

  plug :action

  @moduledoc """
  This module contains the controller for managing SystemEvents
  """  

  @sendable_fields [
    :id, 
    :type, 
    :message, 
    :severity, 
    :data,
    :inserted_at, 
    :updated_at,
  ]

  @doc """
  GET /system_events - Retrieve all SystemEvents for a lookback period
    * Query Parameters:  
      * lookback - integer, defaults to 24 (specify 0 for all)

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(term, [any]) :: term
  def index(conn, params) do
    lookback = if params["lookback"] != nil do
      {int, _} = Integer.parse(params["lookback"])
      int
    else
      24
    end

    json conn, convert_raw(Repo.all(SystemEventQuery.get_events(lookback)))
  end

  @doc """
  POST /system_events - Create a SystemEvent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t
  def create(conn, params) do
    data = if params["data"] != nil do
      Poison.encode!(params["data"])
    else
      nil
    end

    changeset = SystemEvent.new(%{
      type: params["type"],
      message: params["message"],
      severity: params["severity"],
      data: data
    })
    if changeset.valid? do
      try do
        _event = Repo.insert!(changeset)
        path = OpenAperture.Manager.Router.Helpers.system_events_path(Endpoint, :index)

        # Set location header
        created(conn, path)
      rescue
        e -> internal_server_error(conn, "SystemEvent", e ) 
      end
    else
      bad_request(conn, "SystemEvent", changeset.errors)
    end
  end

  @doc false
  # Method to convert an array of DB.Models.SystemEvents into an array of List of SystemEvents
  #
  # Options
  #
  # The `raw_workflows` option defines the array of structs of the DB.Models.SystemEvents to be parsed
  #
  ## Return Values
  #
  # List of parsed SystemEvents
  #
  def convert_raw(raw) do
    case raw do
      nil -> []
      [] -> []
      _ ->
        Enum.reduce raw, [], fn(raw, events) -> 
          event = FormatHelper.to_sendable(raw, @sendable_fields)
          if (event != nil) do
            #stored as String in the db
            if (event[:data] != nil) do
              event = Map.put(event, :data, Poison.decode!(event[:data]))
            end

            events = events ++ [event]
          end

          events
        end
    end
  end  
end