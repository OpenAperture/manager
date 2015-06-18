defmodule OpenAperture.Manager.Controllers.ResponseFormatter do

  @moduledoc """
  This module contains helper methods for returning properly populated Plug.Conn's
  """  

	defmacro __using__(_) do
    quote do
    	require Logger
    	
			alias OpenAperture.Manager.Controllers.FormatHelper
			alias OpenAperture.Manager.Controllers.ResponseBodyFormatter

		  @doc """
		  Method to return a 200 response with accompanying JSON body

		  ## Options
		  The `conn` option defines the underlying Plug connection

		  The `raw_body` option defines the body that should be converted into JSON

		  The `sendable_fields` option defines which fields in the raw_body should be carried over to JSON

		  ## Return Values

		  Underlying Plug connection
		  """
		  @spec ok(Plug.Conn.t, term, List.t) :: Plug.Conn.t
			def ok(conn, raw_body, sendable_fields) do
			  json conn, FormatHelper.to_sendable(raw_body, sendable_fields)
			end

		  @doc """
		  Method to return a 201 response with accompanying Location header

		  ## Options
		  The `conn` option defines the underlying Plug connection

		  The `location` option defines an optional Location; defaults to ""

		  ## Return Values

		  Underlying Plug connection
		  """
		  @spec created(Plug.Conn.t, String.t) :: Plug.Conn.t
			def created(conn, location \\ "") do
			  conn
			  |> put_resp_header("location", location)
			  |> resp(:created, "")
			end

		  @doc """
		  Method to return a 204 response with accompanying Location header

		  ## Options
		  The `conn` option defines the underlying Plug connection

		  The `location` option defines an optional Location; defaults to ""

		  ## Return Values

		  Underlying Plug connection
		  """
		  @spec no_content(Plug.Conn.t, String.t) :: Plug.Conn.t
			def no_content(conn, location \\ "") do
			  conn
			  |> put_resp_header("location", location)
			  |> resp(:no_content, "")
			end

		  @doc """
		  Method to return a 400 response with accompanying JSON body

		  ## Options
		  The `conn` option defines the underlying Plug connection

		  The `item_name` option defines the name of the Model that had a bad response

		  The `changeset_errors` option defines a Keyword list of errors from an Ecto changeset

		  ## Return Values

		  Underlying Plug connection
		  """
		  @spec bad_request(Plug.Conn.t, String.t, List.t) :: Plug.Conn.t
			def bad_request(conn, item_name, changeset_errors \\ []) do
		    conn 
		    |> put_status(:bad_request) 
		    |> json ResponseBodyFormatter.error_body(changeset_errors, item_name)
			end

		  @doc """
		  Method to return a 404 response with accompanying JSON body

		  ## Options
		  The `conn` option defines the underlying Plug connection

		  The `item_name` option defines the name of the Model that could not be found

		  ## Return Values

		  Underlying Plug connection
		  """
		  @spec not_found(Plug.Conn.t, String.t) :: Plug.Conn.t
			def not_found(conn, item_name) do
		    conn 
		    |> put_status(:not_found) 
		    |> json ResponseBodyFormatter.error_body(:not_found, item_name)
			end

		  @doc """
		  Method to return a 409 response with accompanying JSON body

		  ## Options
		  The `conn` option defines the underlying Plug connection

		  The `item_name` option defines the name of the Model that had a conflict

		  ## Return Values

		  Underlying Plug connection
		  """
		  @spec conflict(Plug.Conn.t, String.t) :: Plug.Conn.t
			def conflict(conn, item_name) do
		    conn 
		    |> put_status(:conflict) 
		    |> json ResponseBodyFormatter.error_body(:conflict, item_name)
			end

		  @doc """
		  Method to return a 500 response

		  ## Options
		  The `conn` option defines the underlying Plug connection

		  The `item_name` option defines the name of the Model that had an internal server error

		  The `exception` option may optionally provide the Exception that triggered the 500

		  ## Return Values

		  Underlying Plug connection
		  """
		  @spec internal_server_error(Plug.Conn.t, String.t, term) :: Plug.Conn.t
			def internal_server_error(conn, item_name, exception \\ nil) do
				if exception != nil do
					Logger.error("An Internal Server Error was generated for #{item_name}:  #{inspect exception}")
				end

		    conn 
		    |> put_status(:internal_server_error) 
		    |> json ResponseBodyFormatter.error_body(:internal_server_error, item_name)
			end
		end
	end
end