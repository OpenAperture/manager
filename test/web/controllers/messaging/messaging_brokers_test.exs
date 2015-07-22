defmodule OpenAperture.Manager.Controllers.MessagingBrokersTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenAperture.Manager.DB.Models.MessagingBrokerConnection
  alias OpenAperture.Manager.Repo

  import Ecto.Query

  @endpoint OpenAperture.Manager.Endpoint

  setup do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn ->
      :meck.unload
      Repo.delete_all(MessagingExchangeBroker)
      Repo.delete_all(MessagingBrokerConnection)
      Repo.delete_all(MessagingBroker)
      Repo.delete_all(MessagingExchange)
    end

    :ok
  end

  test "index - no brokers" do
    conn = get conn(), "/messaging/brokers"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index - brokers" do
    changeset = MessagingBroker.new(%{name: "#{UUID.uuid1()}"})
    broker = Repo.insert!(changeset)

    conn = get conn(), "/messaging/brokers"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_broker = List.first(body)
    assert returned_broker != nil
    assert returned_broker["id"] == broker.id
    assert returned_broker["name"] == broker.name
  end

  test "show - invalid broker" do
    conn = get conn(), "/messaging/brokers/1234567890"

    assert conn.status == 404
  end

  test "show - valid broker" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = get conn(), "/messaging/brokers/#{broker.id}"

    assert conn.status == 200

    returned_broker = Poison.decode!(conn.resp_body)
    assert returned_broker != nil
    assert returned_broker["id"] == broker.id
    assert returned_broker["name"] == broker.name
  end

  test "create - conflict" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    conn = post conn(), "/messaging/brokers", [name: broker.name]

    assert conn.status == 409
  end

  test "create - bad request" do
    conn = post conn(), "/messaging/brokers", []
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert!, fn _ -> raise "bad news bears" end)
    conn = post conn(), "/messaging/brokers", [name: "#{UUID.uuid1()}"]
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success" do
    name = "#{UUID.uuid1()}"
    conn = post conn(), "/messaging/brokers", [name: name]

    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/messaging/brokers/")
  end

  test "update - conflict" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    broker2 = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = put conn(), "/messaging/brokers/#{broker.id}", [name: broker2.name]
    
    assert conn.status == 409
  end

  test "update - bad request" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = put conn(), "/messaging/brokers/#{broker.id}", []
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "update - internal server error" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :update!, fn _ -> raise "bad news bears" end)

    conn = put conn(), "/messaging/brokers/#{broker.id}", [name: "#{UUID.uuid1()}"]
    
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "update - success" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    name = "#{UUID.uuid1()}"
    conn = put conn(), "/messaging/brokers/#{broker.id}", [name: name]

    assert conn.status == 204
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/messaging/brokers/")
    updated_broker = Repo.get(MessagingBroker, broker.id)
    assert updated_broker.name == name
  end

  test "destroy - invalid broker" do
    conn = delete conn(), "/messaging/brokers/1234567890"
    
    assert conn.status == 404
  end

  test "destroy - valid broker" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = delete conn(), "/messaging/brokers/#{broker.id}"

    assert conn.status == 204

    assert Repo.get(MessagingBroker, broker.id) == nil
  end

  test "create_connection - success" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = post conn(), "/messaging/brokers/#{broker.id}/connections", [
      username: "username",
      password: "123abc",
      host: "host",
      virtual_host: "vhost"
    ]

    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/connections")
    
    query = from b in MessagingBrokerConnection,
      where: b.messaging_broker_id == ^broker.id,
      select: b
    connections = Repo.all(query)
    assert connections != nil
    assert length(connections) == 1
    connection = List.first(connections)
    
    assert connection != nil
    assert connection != nil
    assert connection.id != nil
    assert connection.messaging_broker_id == broker.id
    assert connection.username == "username"
    assert connection.password != "123abc" #now encrypted
    assert connection.host == "host"
    assert connection.virtual_host == "vhost"    
  end

  test "get_connections - success" do
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    conn = post conn(), "/messaging/brokers/#{broker.id}/connections", [
      username: "username",
      password: "123abc",
      host: "host",
      virtual_host: "vhost"
    ]
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/connections")
    
    conn = get conn(), "/messaging/brokers/#{broker.id}/connections", %{}
    assert conn.status == 200
    connections = Poison.decode!(conn.resp_body)
    assert connections != nil
    assert length(connections) == 1

    connection = List.first(connections)
    assert connection != nil
    assert connection["id"] != nil
    assert connection["messaging_broker_id"] == broker.id
    assert connection["username"] == "username"
    assert connection["password"] == "123abc" #now decrypted
    assert connection["host"] == "host"
    assert connection["virtual_host"] == "vhost"
  end
end