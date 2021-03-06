#
# == messaging_brokers.ex
#
# This module contains the controllers for managing MessagingBrokers
#
require Logger

defmodule OpenAperture.Manager.Controllers.MessagingBrokers do
  use OpenAperture.Manager.Web, :controller

  require Repo

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenAperture.Manager.DB.Models.MessagingBrokerConnection
  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  
  alias OpenAperture.Manager.Controllers.FormatHelper
  alias OpenAperture.Manager.Controllers.ResponseBodyFormatter
  
  import Ecto.Query

  @moduledoc """
  This module contains the controllers for managing MessagingBrokers
  """  

  @sendable_broker_fields [:id, :name, :inserted_at, :failover_broker_id, :updated_at]
  @updatable_broker_fields ["name", "failover_broker_id"]

  @sendable_broker_connection_fields [:id, :messaging_broker_id, :username, :password, :host, :port, :virtual_host, :inserted_at, :updated_at]
  @encrypted_broker_connection_fields [:password]

  @doc """
  GET /messaging/brokers - Retrieve all MessagingBrokers

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_index, do: %{
    description: "Retrieve all MessagingBrokers",
    response_schema: %{"title" => "MessagingBrokers", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.MessagingBroker"}},
    parameters: []
  }    
  @spec index(Plug.Conn.t, [any]) :: Plug.Conn.t
  def index(conn, _params) do
    json conn, FormatHelper.to_sendable(Repo.all(MessagingBroker), @sendable_broker_fields)
  end

  @doc """
  GET /messaging/brokers/:id - Retrieve a MessagingBroker

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_show, do: %{
    description: "Retrieve a specific MessagingBroker",
    response_schema: %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.MessagingBroker"},
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "MessagingBroker identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec show(Plug.Conn.t, [any]) :: Plug.Conn.t
  def show(conn, %{"id" => id}) do
    case Repo.get(MessagingBroker, id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
      broker -> 
        json conn, broker |> FormatHelper.to_sendable(@sendable_broker_fields)
    end
  end

  @doc """
  POST /messaging/brokers - Create a MessagingBroker

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_create, do: %{
    description: "Create a MessagingBroker" ,
    parameters: [%{
      "name" => "type",
      "in" => "body",
      "description" => "The new MessagingBroker",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.MessagingBroker"}
    }]
  }
  @spec create(Plug.Conn.t, [any]) :: Plug.Conn.t
  def create(conn, %{"name" => name} = params) when name != "" do
    query = from b in MessagingBroker,
      where: b.name == ^name,
      select: b
    case Repo.all(query) do
      [] ->
        changeset = MessagingBroker.new(%{
          "name" => name,
          "failover_broker_id" => params["failover_broker_id"]
        })
        if changeset.valid? do
          try do
            broker = Repo.insert!(changeset)
            path = OpenAperture.Manager.Router.Helpers.messaging_brokers_path(Endpoint, :show, broker.id)

            # Set location header
            conn
            |> put_resp_header("location", path)
            |> resp(:created, "")
          rescue
            e ->
              Logger.error("Error inserting broker record for #{name}: #{inspect e}")
              conn
              |> put_status(:internal_server_error)
              |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingBroker")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingBroker")
        end
      _ ->
        conn
        |> put_status(:conflict)
        |> json ResponseBodyFormatter.error_body(:conflict, "MessagingBroker")
    end
  end

  # This action only matches if a param is missing
  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json ResponseBodyFormatter.error_body(:bad_request, "MessagingBroker")
  end

  @doc """
  PUT/PATCH /messaging/brokers/:id - Update a MessagingBroker

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_update, do: %{
    description: "Update a MessagingBroker" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "MessagingBroker identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The updated MessagingBroker",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.MessagingBroker"}
    }]
  }  
  @spec update(Plug.Conn.t, [any]) :: Plug.Conn.t
  def update(conn, %{"id" => id} = params) do
    broker = Repo.get(MessagingBroker, id)

    if broker == nil do
      conn 
      |> put_status(:not_found) 
      |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
    else
    	changeset = MessagingBroker.new(%{
        "name" => params["name"],
        "failover_broker_id" => params["failover_broker_id"]
      })
      if changeset.valid? do
        # Check to see if there is another broker with the same name
    		query = from b in MessagingBroker,
          where: b.name == ^params["name"],
          select: b

        case Repo.all(query) do
          [] ->
          	changeset = MessagingBroker.update(broker, Map.take(params, @updatable_broker_fields))

          	try do
	            Repo.update!(changeset)
	            path = OpenAperture.Manager.Router.Helpers.messaging_brokers_path(Endpoint, :show, id)
	            conn
	            |> put_resp_header("location", path)
	            |> resp(:no_content, "")
	          rescue
	            e ->
	              Logger.error("Error inserting broker record for #{params["name"]}: #{inspect e}")
	              conn 
                |> put_status(:internal_server_error) 
                |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingBroker")
	          end	            
          _ ->
            conn 
            |> put_status(:conflict) 
            |> json ResponseBodyFormatter.error_body(:conflict, "MessagingBroker")
        end
      else
        conn 
        |> put_status(:bad_request) 
        |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingBroker")
      end
    end
  end

  # This action only matches if a param is missing
  def update(conn, _params) do
    conn |> put_status(:bad_request) |> json ResponseBodyFormatter.error_body(:bad_request, "MessagingBroker")
  end

  @doc """
  DELETE /messaging/brokers/:id - Delete a MessagingBroker

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_destroy, do: %{
    description: "Delete a MessagingBroker" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "MessagingBroker identifier",
      "required" => true,
      "type" => "integer"
    }]
  }  
  @spec destroy(Plug.Conn.t, [any]) :: Plug.Conn.t
  def destroy(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingBroker, id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
      broker ->
        Repo.transaction(fn ->
          Repo.update_all(from(c in MessagingBroker, where: c.failover_broker_id  == ^id), set: [failover_broker_id: nil])
          Repo.delete_all(from(c in MessagingBrokerConnection, where: c.messaging_broker_id == ^id))
          Repo.delete_all(from(b in MessagingExchangeBroker, where: b.messaging_broker_id  == ^id))          
          Repo.delete!(broker)
        end)
        resp(conn, :no_content, "")
    end
  end

  @doc """
  POST /messaging/brokers/:id/connections - Add a MessagingBrokerConnection

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_create_connection, do: %{
    description: "Create a MessagingBrokerConnection" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "MessagingBroker identifier",
      "required" => true,
      "type" => "integer"
    },
    %{
      "name" => "type",
      "in" => "body",
      "description" => "The new MessagingBrokerConnection",
      "required" => true,
      "schema": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.MessagingBrokerConnection"}
    }]
  }
  @spec create_connection(Plug.Conn.t, [any]) :: Plug.Conn.t
  def create_connection(conn, %{"id" => id} = params) do
    try do
      case Repo.get(MessagingBroker, id) do
        nil -> 
          conn
          |> put_status(:not_found)
          |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
        broker ->
    		  changeset = MessagingBrokerConnection.new(%{
	        	messaging_broker_id: id,
	        	username: params["username"],
	        	password: FormatHelper.encrypt_value(params["password"]),
	        	password_keyname: Application.get_env(:openaperture_messaging, :keyname, ""),
	        	host: params["host"],
	        	virtual_host: params["virtual_host"],
	        })
	        case changeset.valid? do
            true -> 
              _connection = Repo.insert!(changeset)
              path = OpenAperture.Manager.Router.Helpers.messaging_brokers_path(Endpoint, :get_connections, broker.id)

              # Set location header
              conn
              |> put_resp_header("location", path)
              |> resp(:created, "")
            _ ->
  	          conn
              |> put_status(:bad_request)
              |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingBroker")
	        end
      end
    rescue
      e -> 
        Logger.error("Error inserting connection for broker #{params["host"]}: #{inspect e}")
        conn
        |> put_status(:internal_server_error)
        |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingBroker")
    end
  end

  @doc """
  GET /messaging/brokers/:id/connections - Retrieve all MessagingBrokerConnections for a broker

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_get_connections, do: %{
    description: "Retrieve all MessagingBrokerConnections for a broker",
    response_schema: %{"title" => "MessagingBrokerConnections", "type": "array", "items": %{"$ref": "#/definitions/OpenAperture.Manager.DB.Models.MessagingBrokerConnection"}},
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "MessagingBroker identifier",
      "required" => true,
      "type" => "integer"
    }]
  }    
  @spec get_connections(Plug.Conn.t, [any]) :: Plug.Conn.t
  def get_connections(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingBroker, id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
      _broker -> 
      	query = from b in MessagingBrokerConnection,
      		where: b.messaging_broker_id == ^id,
      		select: b
      	connections = Repo.all(query)
      	cond do
      		connections == nil -> json conn, []
      		connections != nil && length(connections) == 1 ->
      			sendable_connection = FormatHelper.to_sendable(List.first(connections), @sendable_broker_connection_fields, @encrypted_broker_connection_fields)
      			json conn, [sendable_connection]
      		true ->
      			sendable_connections = Enum.reduce(connections, [], fn (connection, sendable_connections) ->
  	      			sendable_connections ++ [FormatHelper.to_sendable(connection, @sendable_broker_connection_fields, @encrypted_broker_connection_fields)]
  	      		end)
	      		json conn, sendable_connections
      	end
    end
  end

  @doc """
  DELETE /messaging/brokers/:id/connections - Delete MessagingBrokerConnections

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  def swaggerdoc_destroy_connections, do: %{
    description: "Delete all MessagingBrokerConnection" ,
    parameters: [%{
      "name" => "id",
      "in" => "path",
      "description" => "MessagingBroker identifier",
      "required" => true,
      "type" => "integer"
    }]
  }  
  @spec destroy_connections(Plug.Conn.t, [any]) :: Plug.Conn.t
  def destroy_connections(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingBroker, id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
      _broker ->
        Repo.transaction(fn ->
          Repo.delete_all(from(c in MessagingBrokerConnection, where: c.messaging_broker_id == ^id))
        end)
        resp(conn, :no_content, "")
    end
  end
end