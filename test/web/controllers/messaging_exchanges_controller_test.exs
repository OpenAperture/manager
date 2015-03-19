defmodule ProjectOmeletteManager.Web.Controllers.MessagingExchangesController.Test do
  use ExUnit.Case
  use Plug.Test
  use ProjectOmeletteManager.Test.ConnHelper

  alias ProjectOmeletteManager.DB.Models.MessagingExchange
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.Router

  import Ecto.Query

  setup do
    on_exit fn -> 
      Repo.delete_all(MessagingExchange)
    end
  end

  test "index - no exchanges" do
    conn = call(Router, :get, "/messaging/exchanges")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index - exchanges" do
    changeset = MessagingExchange.new(%{name: "#{UUID.uuid1()}"})
    exchange = Repo.insert(changeset)

    conn = call(Router, :get, "/messaging/exchanges")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_exchange = List.first(body)
    assert returned_exchange != nil
    assert returned_exchange["id"] == exchange.id
    assert returned_exchange["name"] == exchange.name
  end

  test "show - invalid exchange" do
    conn = call(Router, :get, "/messaging/exchanges/1234567890")
    assert conn.status == 404
  end

  test "show - valid exchange" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :get, "/messaging/exchanges/#{exchange.id}")
    assert conn.status == 200

    returned_exchange = Poison.decode!(conn.resp_body)
    assert returned_exchange != nil
    assert returned_exchange["id"] == exchange.id
    assert returned_exchange["name"] == exchange.name
  end

  test "create - conflict" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :post, "/messaging/exchanges", %{"name" => exchange.name})
    assert conn.status == 409
  end

  test "create - bad request" do
    conn = call(Router, :post, "/messaging/exchanges", %{})
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert, fn _ -> raise "bad news bears" end)

    conn = call(Router, :post, "/messaging/exchanges", %{"name" => "#{UUID.uuid1()}"})
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success" do
    name = "#{UUID.uuid1()}"
    conn = call(Router, :post, "/messaging/exchanges", %{"name" => name})
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/messaging/exchanges/")
  end

 test "update - conflict" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    exchange2 = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :put, "/messaging/exchanges/#{exchange.id}", %{"name" => exchange2.name})
    assert conn.status == 409
  end

  test "update - bad request" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :put, "/messaging/exchanges/#{exchange.id}", %{})
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "update - internal server error" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :update, fn _ -> raise "bad news bears" end)

    conn = call(Router, :put, "/messaging/exchanges/#{exchange.id}", %{"name" => "#{UUID.uuid1()}"})
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "update - success" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    name = "#{UUID.uuid1()}"
    conn = call(Router, :put, "/messaging/exchanges/#{exchange.id}", %{"name" => name})
    assert conn.status == 204
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/messaging/exchanges/")
    updated_exchange = Repo.get(MessagingExchange, exchange.id)
    assert updated_exchange.name == name
  end

  test "destroy - invalid exchange" do
    conn = call(Router, :delete, "/messaging/exchanges/1234567890")
    assert conn.status == 404
  end

  test "destroy - valid exchange" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :delete, "/messaging/exchanges/#{exchange.id}")
    assert conn.status == 204

    assert Repo.get(MessagingExchange, exchange.id) == nil
  end
end