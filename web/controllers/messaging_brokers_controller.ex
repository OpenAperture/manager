#
# == connection_pools.ex
#
# This module contains the controllers for managing MessagingBrokers
#
require Logger

defmodule ProjectOmeletteManager.MessagingBrokersController do
  use ProjectOmeletteManager.Web, :controller

  alias ProjectOmeletteManager.Endpoint
  alias ProjectOmeletteManager.DB.Models.MessagingBroker
  alias ProjectOmeletteManager.DB.Models.MessagingBrokerConnection
  
  import Ecto.Query

  # TODO: Add authentication

  plug :action

  @moduledoc """
  This module contains the controllers for managing MessagingBrokers
  """  

  @sendable_broker_fields [:id, :name, :inserted_at, :updated_at]
  @updatable_broker_fields ["name"]

	@sendable_broker_connection_fields [:id, :messaging_broker_id, :username, :password, :host, :virtual_host, :inserted_at, :updated_at]

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
      nil -> resp(conn, :not_found, "")
      broker -> json conn, broker |> to_sendable(@sendable_broker_fields)
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
  def create(conn, %{"name" => name} = _params) when name != "" do
    query = from b in MessagingBroker,
      where: b.name == ^name,
      select: b
    case Repo.all(query) do
      [] ->
        changeset = MessagingBroker.new(%{"name" => name})
        if changeset.valid? do
          try do
            broker = Repo.insert(changeset)
            path = ProjectOmeletteManager.Router.Helpers.messaging_brokers_path(Endpoint, :show, broker.id)

            # Set location header
            conn
            |> put_resp_header("location", path)
            |> resp(:created, "")
          rescue
            e ->
              Logger.error("Error inserting broker record for #{name}: #{inspect e}")
              resp(conn, :internal_server_error, "")
          end
        else
          conn
          |> put_status(:bad_request)
          |> json keywords_to_map(changeset.errors)
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
      resp(conn, :not_found, "")
    else
    	changeset = MessagingBroker.new(%{"name" => params["name"]})
      if changeset.valid? do
        # Check to see if there is another broker with the same name
    		query = from b in MessagingBroker,
          where: b.name == ^params["name"],
          select: b

        case Repo.all(query) do
          [] ->
          	changeset = MessagingBroker.changeset(broker, Map.take(params, @updatable_broker_fields))

          	try do
	            Repo.update(changeset)
	            path = ProjectOmeletteManager.Router.Helpers.messaging_brokers_path(Endpoint, :show, id)
	            conn
	            |> put_resp_header("location", path)
	            |> resp(:no_content, "")
	          rescue
	            e ->
	              Logger.error("Error inserting broker record for #{params["name"]}: #{inspect e}")
	              resp(conn, :internal_server_error, "")
	          end	            
          _ ->
            resp(conn, :conflict, "")
        end
      else
        conn
        |> put_status(:bad_request)
        |> json keywords_to_map(changeset.errors)
      end
    end
  end

  # This action only matches if a param is missing
  def update(conn, _params) do
    resp(conn, :bad_request, "name is required")
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
      nil -> resp(conn, :not_found, "")
      broker ->
        Repo.transaction(fn ->
          Repo.delete_all(from(c in MessagingBrokerConnection, where: c.messaging_broker_id == ^id))
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
      nil -> resp(conn, :not_found, "")
      broker ->
      	case encrypt_password(params["password"]) do
      		nil -> resp(conn, :internal_server_error, "")
      		encrypted_password ->
		        changeset = MessagingBrokerConnection.new(%{
		        	messaging_broker_id: id,
		        	username: params["username"],
		        	password: encrypted_password,
		        	password_keyname: Application.get_env(:cloudos_messaging, :keyname, ""),
		        	host: params["host"],
		        	virtual_host: params["virtual_host"],
		        })
		        if changeset.valid? do
		          try do
		            connection = Repo.insert(changeset)
		            path = ProjectOmeletteManager.Router.Helpers.messaging_brokers_path(Endpoint, :get_connections, broker.id)

		            # Set location header
		            conn
		            |> put_resp_header("location", path)
		            |> resp(:created, "")
		          rescue
		            e ->
		              Logger.error("Error inserting connection for broker #{params["host"]}: #{inspect e}")
		              resp(conn, :internal_server_error, "")
		          end
		        else
		          conn
		          |> put_status(:bad_request)
		          |> json keywords_to_map(changeset.errors)
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
  		keyfile =  Application.get_env(:cloudos_messaging, :public_key)
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
  defp decrypt_password(encrypted_password) do
  	try do
  		keyfile =  Application.get_env(:cloudos_messaging, :private_key)
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
  def get_connections(conn, %{"id" => id} = params) do
    case Repo.get(MessagingBroker, id) do
      nil -> resp(conn, :not_found, "")
      broker -> 
      	query = from b in MessagingBrokerConnection,
      		where: b.messaging_broker_id == ^id,
      		select: b
      	connections = Repo.all(query)
      	cond do
      		connections == nil -> json conn, []
      		connections != nil && length(connections) == 1 ->
      			sendable_connection = to_sendable(List.first(connections), @sendable_broker_connection_fields)
      			json conn, [Map.put(sendable_connection, :password, decrypt_password(sendable_connection[:password]))]
      		true ->
      			sendable_connections = Enum.reduce connections, [], fn (connection, sendable_connections) ->
	      			sendable_connection = to_sendable(connection, @sendable_broker_connection_fields)
	      			sendable_connections ++ [Map.put(sendable_connection, "password", decrypt_password(sendable_connection["password"]))]
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
      nil -> resp(conn, :not_found, "")
      broker ->
        Repo.transaction(fn ->
          Repo.delete_all(from(c in MessagingBrokerConnection, where: c.messaging_broker_id == ^id))
        end)
        resp(conn, :no_content, "")
    end
  end

  defp to_sendable(%{__struct__: _} = struct, allowed_fields) do
    struct
    |> Map.from_struct
    |> Map.take(allowed_fields)
  end

  @doc """
  keywords_to_map converts a keyword list to a map, which is more easily
  transmitted as a JSON object. If a key is repeated in the keyword list, then
  the value in the map is represented as a list.
  Ex:
  [a: "First value", b: "Second value", c: "Third value"] becomes
  %{a: ["First value", "Third value"], b: "Second value"}
  """
  @spec keywords_to_map(Keyword) :: Map
  defp keywords_to_map(kw) do
    kw
    |> Enum.reduce(
      %{},
      fn {key, value}, acc ->
        current = acc[key]
        case current do
          nil -> Map.put(acc, key, value)
          [single] -> Map.put(acc, key, [single, value])
          [_ | _] -> Map.put(acc, key, current ++ [value])
          _ -> Map.put(acc, key, [current, value])
        end
      end)
  end
end