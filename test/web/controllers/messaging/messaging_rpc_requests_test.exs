defmodule OpenAperture.Manager.Controllers.MessagingRpcRequestsTest do
  use ExUnit.Case
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  alias OpenAperture.Manager.DB.Models.MessagingRpcRequest
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Router

  setup_all _context do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit _context, fn ->
      try do
        :meck.unload(OpenAperture.Manager.Plugs.Authentication)
      rescue _ -> IO.puts "" end
    end    
    :ok
  end

  setup do
    on_exit fn -> 
      Repo.delete_all(MessagingRpcRequest)
    end
  end

  test "index - no requests" do
    conn = call(Router, :get, "/messaging/rpc_requests")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index - requests" do
    changeset = MessagingRpcRequest.new(%{status: to_string(:not_started)})
    request = Repo.insert(changeset)

    conn = call(Router, :get, "/messaging/rpc_requests")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_request = List.first(body)
    assert returned_request != nil
    assert returned_request["id"] == request.id
  end

  test "show - invalid request" do
    conn = call(Router, :get, "/messaging/rpc_requests/1234567890")
    assert conn.status == 404
  end

  test "show - valid request" do
    request = Repo.insert(MessagingRpcRequest.new(%{status: to_string(:not_started)}))

    conn = call(Router, :get, "/messaging/rpc_requests/#{request.id}")
    assert conn.status == 200

    returned_request = Poison.decode!(conn.resp_body)
    assert returned_request != nil
    assert returned_request["id"] == request.id
  end

  test "show - valid request with data" do
    request = Repo.insert(MessagingRpcRequest.new(%{
      status: to_string(:not_started),
      request_body: Poison.encode!(%{
        "etcd_token" => "123abc",
        "action_parameters" => nil,
        "action" => "list_machines"
      }),
      response_body: Poison.encode!(%{
        "errors" => ["Message 2 Caught :error with %RuntimeError{message: \"No valid nodes were found.\"}"]
      }),
    }))

    conn = call(Router, :get, "/messaging/rpc_requests/#{request.id}")
    assert conn.status == 200

    returned_request = Poison.decode!(conn.resp_body)
    assert returned_request != nil
    assert returned_request["id"] == request.id
    assert returned_request["request_body"] != nil
    assert returned_request["response_body"] != nil
  end

  test "create - bad request" do
    conn = call(Router, :post, "/messaging/rpc_requests", %{})
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert, fn _ -> raise "bad news bears" end)

    conn = call(Router, :post, "/messaging/rpc_requests", %{"status" => "not_started", "request_body" => %{}})
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success" do
    conn = call(Router, :post, "/messaging/rpc_requests", %{"status" => "not_started", "request_body" => %{}})
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/messaging/rpc_requests/")
  end

  test "update - bad request" do
    request = Repo.insert(MessagingRpcRequest.new(%{status: to_string(:not_started)}))

    conn = call(Router, :put, "/messaging/rpc_requests/#{request.id}", %{})
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "update - internal server error" do
    request = Repo.insert(MessagingRpcRequest.new(%{status: to_string(:not_started)}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :update, fn _ -> raise "bad news bears" end)

    conn = call(Router, :put, "/messaging/rpc_requests/#{request.id}", %{"status" => "not_started", "request_body" => %{}})
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "update - success" do
    request = Repo.insert(MessagingRpcRequest.new(%{status: to_string(:not_started)}))

    conn = call(Router, :put, "/messaging/rpc_requests/#{request.id}", %{"status" => "not_started", "request_body" => %{}})
    assert conn.status == 204
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/messaging/rpc_requests/")
    updated_request = Repo.get(MessagingRpcRequest, request.id)
    assert updated_request != nil
  end

  test "destroy - invalid request" do
    conn = call(Router, :delete, "/messaging/rpc_requests/1234567890")
    assert conn.status == 404
  end

  test "destroy - valid request" do
    request = Repo.insert(MessagingRpcRequest.new(%{status: to_string(:not_started)}))

    conn = call(Router, :delete, "/messaging/rpc_requests/#{request.id}")
    assert conn.status == 204

    assert Repo.get(MessagingRpcRequest, request.id) == nil
  end
end