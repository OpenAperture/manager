require Logger

defmodule OpenAperture.Manager.Controllers.SystemEvents do
  use OpenAperture.Manager.Web, :controller
  use Timex
  
  require Repo

  alias OpenAperture.Manager.DB.Models.SystemEvent
  alias OpenAperture.Manager.DB.Queries.SystemEvent, as: SystemEventQuery

  alias OpenAperture.Manager.DB.Models.User

  alias OpenAperture.Manager.Notifications.Publisher
  alias OpenAperture.Manager.Configuration

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
    :dismissed_at,
    :dismissed_by_id,
    :dismissed_reason,
    :assigned_at,
    :assignee_id,
    :assigned_by_id    
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
  def swaggerdoc_index, do: %{
    description: "Retrieve a set of SystemEvents" ,
    parameters: [%{
      "name" => "lookback",
      "in" => "query",
      "description" => "The number of hours (back) to retrieve SystemEvents, defaults to 24",
      "required" => false,
      "type" => "integer"
    }, 
    %{
      "name" => "assignee_id",
      "in" => "query",
      "description" => "Retrieves all events (no time-range) for the User identifier",
      "required" => false,
      "type" => "integer"
    }]
  }  
  @spec index(term, [any]) :: term
  def index(conn, params) do
    query = cond do
      #check for lookback query
      params["lookback"] != nil -> 
        {int, _} = Integer.parse(params["lookback"])
        SystemEventQuery.get_events(int)

      #check for user-assigned
      params["assignee_id"] != nil -> SystemEventQuery.get_assigned_events(params["assignee_id"])

      #default to a 24-hour lookback
      true -> SystemEventQuery.get_events(24)
    end

    json conn, convert_raw(Repo.all(query))
  end

  @doc """
  GET /system_events/:id - Retrieve a SystemEvent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_show, do: %{
    description: "Retrieve a set of SystemEvents" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "SystemEvent identifier",
      "required" => true,
      "type" => "integer"
    }]
  }  
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t
  def show(conn, params) do
    case Repo.get(SystemEvent, params["id"]) do
      nil -> not_found(conn, "SystemEvent #{params["id"]}")
      event -> 
        json conn, List.first(convert_raw([event]))
    end
  end  

  @doc """
  POST /system_events - Create a SystemEvent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_create, do: %{
    description: "Create a SystemEvents" ,
    parameters: [%{
      "name" => "type",
      "in" => "body",
      "description" => "type of SystmEvent",
      "required" => true,
      "type" => "string"
    }, 
    %{
      "name" => "message",
      "in" => "body",
      "description" => "event message",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "severity",
      "in" => "body",
      "description" => "error, warning, info, debug",
      "required" => true,
      "type" => "string"
    },
    %{
      "name" => "data",
      "in" => "body",
      "description" => "Map of data points",
      "required" => false,
      "type" => "map"
    }]
  }    
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

      #unique flag is on, ensure that no other events within the last hour match the criteria
      is_unique = if params["unique"] == true do
        existing_events = Repo.all(SystemEventQuery.get_events(1, params["type"]))
        Enum.reduce existing_events, true, fn(existing_event, is_unique) ->
          existing_data = if existing_event.data != nil do
            Poison.decode!(existing_event.data)
          else
            nil
          end

          cond do
            !is_unique -> is_unique
            params["data"] != nil && existing_data != nil -> !Map.equal?(existing_data, params["data"])
            true -> false
          end
        end
      else
        true
      end

      try do
        if is_unique do
          _event = Repo.insert!(changeset)
          path = OpenAperture.Manager.Router.Helpers.system_events_path(Endpoint, :index)

          # Set location header
          created(conn, path)
        else
          conflict(conn, "SystemEvent")
        end
      rescue
        e -> internal_server_error(conn, "SystemEvent", e ) 
      end
    else
      bad_request(conn, "SystemEvent", changeset.errors)
    end
  end

  @doc """
  POST /system_events/:id/assign - Assign a SystemEvent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_assign, do: %{
    description: "Assign a SystemEvent to a User" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "SystemEvent identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "assignee_id",
      "in" => "body",
      "description" => "User id to which the event will be associated",
      "required" => false,
      "type" => "integer"
    }, 
    %{
      "name" => "assigned_by_id",
      "in" => "body",
      "description" => "User id who assigned the event",
      "required" => false,
      "type" => "integer"
    }]
  }    
  @spec assign(Plug.Conn.t, [any]) :: Plug.Conn.t
  def assign(conn, params) do
    event = Repo.get(SystemEvent, params["id"])

    if params["assignee_id"] != nil do
      assignee = Repo.get(User, params["assignee_id"])
    end

    if conn.private[:auth_user] != nil do
      assigned_by = conn.private[:auth_user]
    end

    cond do
      event == nil -> not_found(conn, "SystemEvent #{params["id"]}")
      assignee == nil -> bad_request(conn, "User #{params["assignee_id"]}")
      assigned_by == nil -> bad_request(conn, "User assigned_by")
      true -> 
        changeset = SystemEvent.validate_changes(event, %{
          assignee_id: assignee.id,
          assigned_by_id: assigned_by.id,
          assigned_at: Ecto.DateTime.utc
        })
        if changeset.valid? do
          try do
            Repo.update!(changeset)
            path = OpenAperture.Manager.Router.Helpers.system_events_path(Endpoint, :show, params["id"])

            #send an email to the assignee (if possible)
            if assignee.email != nil && String.length(assignee.email) > 0 do
              recipients = [assignee.email]
              subject = "[OpenAperture][SystemEvent]"
              body = "System event #{event.id} has been assigned to you:\n  #{event.message}\n\nFor more information, please see:  #{Configuration.get_ui_url}/index.html#/oa/system_events"
              Publisher.email_notification(subject,body,recipients)            
            end

            no_content(conn, path)
          rescue 
            e -> internal_server_error(conn, "SystemEvent", e ) 
          end
        else
          bad_request(conn, "SystemEvent", changeset.errors)
        end            
    end
  end

  @doc """
  POST /system_events/:id/dismiss - Dismiss a SystemEvent

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_dismiss, do: %{
    description: "Dismiss a SystemEvent to a User",
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "SystemEvent identifier",
      "required" => true,
      "type" => "integer"
    }, 
    %{
      "name" => "dismissed_by_id",
      "in" => "body",
      "description" => "User id who dismissed the event, defaults to the request user",
      "required" => false,
      "type" => "integer"
    }]
  }      
  @spec dismiss(Plug.Conn.t, [any]) :: Plug.Conn.t
  def dismiss(conn, params) do
    event = Repo.get(SystemEvent, params["id"])
    if params["dismissed_by_id"] != nil do
      dismissed_by = Repo.get(User, params["dismissed_by_id"])
    else
      dismissed_by = conn.private[:auth_user]
    end

    cond do
      event == nil -> not_found(conn, "SystemEvent #{params["id"]}")
      dismissed_by == nil -> bad_request(conn, "User #{params["dismissed_by_id"]}")
      true -> 
        changeset = SystemEvent.validate_changes(event, %{
          dismissed_by_id: dismissed_by.id,
          dismissed_at: Ecto.DateTime.utc,
          dismissed_reason: params["dismissed_reason"]
          })
        if changeset.valid? do
          try do
            Repo.update!(changeset)
            path = OpenAperture.Manager.Router.Helpers.system_events_path(Endpoint, :show, params["id"])
            
            #send an email to the assignee (if possible)
            if event.assignee_id != nil do
              assignee = Repo.get(User, event.assignee_id)
              if assignee.email != nil && String.length(assignee.email) > 0 do
                recipients = [assignee.email]
                subject = "[OpenAperture][SystemEvent]"
                body = "System event #{event.id} is assigned to you and has been dismissed.  For more information, please see:  #{Configuration.get_ui_url}/index.html#/oa/system_events"
                Publisher.email_notification(subject,body,recipients)            
              end
            end

            no_content(conn, path)
          rescue 
            e -> internal_server_error(conn, "SystemEvent", e ) 
          end
        else
          bad_request(conn, "SystemEvent", changeset.errors)
        end  
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

            if event[:assigned_at] != nil do
              {:ok, erl_date} = Ecto.DateTime.dump(event[:assigned_at])
              date = Date.from(erl_date, :utc)
              event = Map.put(event, :assigned_at, DateFormat.format!(date, "{RFC1123}"))
            end

            if event[:dismissed_at] != nil do
              {:ok, erl_date} = Ecto.DateTime.dump(event[:dismissed_at])
              date = Date.from(erl_date, :utc)
              event = Map.put(event, :dismissed_at, DateFormat.format!(date, "{RFC1123}"))
            end

            events = events ++ [event]
          end

          events
        end
    end
  end  
end