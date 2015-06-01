#
# == messaging_rpc_requests.ex
#
# This module contains the controllers for managing MessagingRpcRequests
#
require Logger

defmodule OpenAperture.Manager.Controllers.MessagingRpcRequests do
  use OpenAperture.Manager.Web, :controller

  require Repo

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.DB.Models.MessagingRpcRequest
  
  alias OpenAperture.Manager.Controllers.FormatHelper
  
  plug :action

  @moduledoc """
  This module contains the controllers for managing MessagingRpcRequests
  """  

  @sendable_fields [:id, :status, :request_body, :response_body, :inserted_at, :updated_at]

  @doc """
  GET /messaging/rpc_requests - Retrieve all MessagingRpcRequest

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec index(term, [any]) :: term
  def index(conn, _params) do
    updated_requests = case Repo.all(MessagingRpcRequest) do
      [] -> []
      raw_requests -> 
        requests = 
          raw_requests
          |> FormatHelper.to_sendable(@sendable_fields) 
          |> FormatHelper.to_string_timestamps

        Enum.reduce requests, [], fn (request, updated_requests) ->
          if (request[:request_body] != nil) do
            request = Map.put(request, :request_body, Poison.decode!(request[:request_body]))
          end

          if (request[:response_body] != nil) do
            request = Map.put(request, :response_body, Poison.decode!(request[:response_body]))
          end
          updated_requests ++ [request]
        end
    end
    json conn, updated_requests
  end

  @doc """
  GET /messaging/rpc_requests/:id - Retrieve a MessagingRpcRequest

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec show(term, [any]) :: term
  def show(conn, %{"id" => id}) do
    case Repo.get(MessagingRpcRequest, id) do
      nil -> resp(conn, :not_found, "")
      raw_request -> 
        request = 
          raw_request
          |> FormatHelper.to_sendable(@sendable_fields) 
          |> FormatHelper.to_string_timestamps

        if (request[:request_body] != nil) do
          request = Map.put(request, :request_body, Poison.decode!(request[:request_body]))
        end

        if (request[:response_body] != nil) do
          request = Map.put(request, :response_body, Poison.decode!(request[:response_body]))
        end

        json conn, request
    end
  end

  @doc """
  POST /messaging/rpc_requests - Create a MessagingRpcRequest

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec create(term, [any]) :: term
  def create(conn, params) do
    request_body = if params["request_body"] != nil do
      Poison.encode!(params["request_body"])
    else
      ""
    end

    response_body = if params["response_body"] != nil do
      Poison.encode!(params["response_body"])
    else
      ""
    end

    changeset = MessagingRpcRequest.new(%{
      "status" => params["status"],
      "request_body" => request_body,
      "response_body" => response_body,
    })
    if changeset.valid? do
      try do
        request = Repo.insert(changeset)
        path = OpenAperture.Manager.Router.Helpers.messaging_rpc_requests_path(Endpoint, :show, request.id)

        # Set location header
        conn
        |> put_resp_header("location", path)
        |> resp(:created, "")
      rescue
        e ->
          Logger.error("Error inserting request record: #{inspect e}")
          resp(conn, :internal_server_error, "")
      end
    else
      conn
      |> put_status(:bad_request)
      |> json FormatHelper.keywords_to_map(changeset.errors)
    end
  end    

  @doc """
  PUT/PATCH /messaging/rpc_requests/:id - Update a MessagingRpcRequest

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec update(term, [any]) :: term
  def update(conn, %{"id" => id} = params) do
    request = Repo.get(MessagingRpcRequest, id)

    if request == nil do
      resp(conn, :not_found, "")
    else
      request_body = if params["request_body"] != nil do
        Poison.encode!(params["request_body"])
      else
        ""
      end

      response_body = if params["response_body"] != nil do
        Poison.encode!(params["response_body"])
      else
        ""
      end

      changeset = MessagingRpcRequest.changeset(request, %{
        "status" => params["status"],
        "request_body" => request_body,
        "response_body" => response_body,
      })
      if changeset.valid? do  
        try do
          Repo.update(changeset)
          path = OpenAperture.Manager.Router.Helpers.messaging_rpc_requests_path(Endpoint, :show, id)
          conn
          |> put_resp_header("location", path)
          |> resp(:no_content, "")
        rescue
          e ->
            Logger.error("Error inserting request record: #{inspect e}")
            resp(conn, :internal_server_error, "")
        end             
      else
        conn
        |> put_status(:bad_request)
        |> json FormatHelper.keywords_to_map(changeset.errors)
      end
    end
  end  

  @doc """
  DELETE /messaging/rpc_requests/:id - Delete a MessagingRpcRequest

  ## Options
  The `conn` option defines the underlying HTTP connection.
  The `params` option defines an array of arguments.

  ## Return Values

  Underlying HTTP connection
  """
  @spec destroy(term, [any]) :: term
  def destroy(conn, %{"id" => id} = _params) do
    case Repo.get(MessagingRpcRequest, id) do
      nil -> resp(conn, :not_found, "")
      request ->
        Repo.transaction(fn ->
          Repo.delete(request)
        end)
        resp(conn, :no_content, "")
    end
  end  
end