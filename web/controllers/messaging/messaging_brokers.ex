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

  # TODO: Add authentication

  plug :action

  @moduledoc """
  This module contains the controllers for managing MessagingBrokers
  """  

  @sendable_broker_fields [:id, :name, :inserted_at, :failover_broker_id, :updated_at]
  @updatable_broker_fields ["name", "failover_broker_id"]

	@sendable_broker_connection_fields [:id, :messaging_broker_id, :username, :password, :host, :port, :virtual_host, :inserted_at, :updated_at]

  @doc """
  GET /messaging/brokers - Retrieve all MessagingBrokers

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(term, [any]) :: term
  def index(conn, _params) do
    json conn, Repo.all(MessagingBroker)
  end

  @doc """
  GET /messaging/brokers/:id - Retrieve a MessagingBroker

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show(term, [any]) :: term
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
  @spec create(term, [any]) :: term
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
            broker = Repo.insert(changeset)
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
  @spec update(term, [any]) :: term
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
	            Repo.update(changeset)
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
  @spec destroy(term, [any]) :: term
  def destroy(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingBroker, id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
      broker ->
        Repo.transaction(fn ->
          Repo.update_all(from(c in MessagingBroker, where: c.failover_broker_id  == ^id), failover_broker_id: nil)
          Repo.delete_all(from(c in MessagingBrokerConnection, where: c.messaging_broker_id == ^id))
          Repo.delete_all(from(b in MessagingExchangeBroker, where: b.messaging_broker_id  == ^id))          
          Repo.delete(broker)
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
  @spec create_connection(term, [any]) :: term
  def create_connection(conn, %{"id" => id} = params) do
    case Repo.get(MessagingBroker, id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json ResponseBodyFormatter.error_body(:not_found, "MessagingBroker")
      broker ->
      	case encrypt_password(params["password"]) do
      		nil -> 
            conn
            |> put_status(:internal_server_error)
            |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingBroker")
      		encrypted_password ->
		        changeset = MessagingBrokerConnection.new(%{
		        	messaging_broker_id: id,
		        	username: params["username"],
		        	password: encrypted_password,
		        	password_keyname: Application.get_env(:openaperture_messaging, :keyname, ""),
		        	host: params["host"],
		        	virtual_host: params["virtual_host"],
		        })
		        if changeset.valid? do
		          try do
		            _connection = Repo.insert(changeset)
		            path = OpenAperture.Manager.Router.Helpers.messaging_brokers_path(Endpoint, :get_connections, broker.id)

		            # Set location header
		            conn
		            |> put_resp_header("location", path)
		            |> resp(:created, "")
		          rescue
		            e ->
		              Logger.error("Error inserting connection for broker #{params["host"]}: #{inspect e}")
		              conn
                  |> put_status(:internal_server_error)
                  |> json ResponseBodyFormatter.error_body(:internal_server_error, "MessagingBroker")
		          end
		        else
              conn
              |> put_status(:bad_request)
              |> json ResponseBodyFormatter.error_body(changeset.errors, "MessagingBroker")
		        end      			
      	end
    end
  end

  @doc false
  # Method to encrypt a password using an RSA key
  #
  ## Options
  # The `password` option represents the password to encrypt
  #
  ## Return Value
  #
  # The encrypted password
  #
  @spec encrypt_password(String.t()) :: String.t()
  defp encrypt_password(password) do
  	try do
  		keyfile =  Application.get_env(:openaperture_messaging, :public_key)
  		if File.exists?(keyfile) do
	  		public_key = RSA.decode_key(File.read!(keyfile))
				cyphertext = password |> RSA.encrypt {:public, public_key}
				"#{:base64.encode_to_string(cyphertext)}"
			else
				Logger.error("Error retrieving public key:  File #{keyfile} does not exist!")
      	nil				
			end
    rescue
      e ->
        Logger.error("Error retrieving public key:  #{inspect e}")
      	nil
    end
  end

  @doc false
  # Method to decrypt a password using an RSA key
  #
  ## Options
  # The `password` option represents the encrypted password
  #
  ## Return Value
  #
  # The decrypted password
  #
  @spec decrypt_password(String.t()) :: String.t()
  def decrypt_password(encrypted_password) do
  	try do
  		keyfile =  Application.get_env(:openaperture_messaging, :private_key)
  		if File.exists?(keyfile) do  		
	  		private_key = RSA.decode_key(File.read!(keyfile))
	  		cyphertext = :base64.decode(encrypted_password)
	  		"#{RSA.decrypt cyphertext, {:private, private_key}}"
			else
				Logger.error("Error retrieving private key:  File #{keyfile} does not exist!")
      	nil				
			end
    rescue
      e ->
        Logger.error("Error retrieving private key:  #{inspect e}")
      	nil
    end  	
  end

  @doc """
  GET /messaging/brokers/:id/connections - Add a MessagingBrokerConnection

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec get_connections(term, [any]) :: term
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
      			sendable_connection = FormatHelper.to_sendable(List.first(connections), @sendable_broker_connection_fields)
      			json conn, [Map.put(sendable_connection, :password, decrypt_password(sendable_connection[:password]))]
      		true ->
      			sendable_connections = Enum.reduce connections, [], fn (connection, sendable_connections) ->
	      			sendable_connection = FormatHelper.to_sendable(connection, @sendable_broker_connection_fields)
	      			sendable_connections ++ [Map.put(sendable_connection, :password, decrypt_password(sendable_connection[:password]))]
	      		end
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
  @spec destroy_connections(term, [any]) :: term
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