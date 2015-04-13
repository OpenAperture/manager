defmodule OpenAperture.Manager.Web.Controllers.MessagingExchangesController.Test do
  use ExUnit.Case
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.Router
  alias OpenAperture.Manager.DB.Models.EtcdCluster

  import Ecto.Query

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
      Repo.delete_all(MessagingExchangeBroker)
      Repo.delete_all(MessagingBroker)
      Repo.delete_all(EtcdCluster)
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

  test "create_broker_restriction - success" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :post, "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    })
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/brokers")
    assert String.contains?(location_header, "/exchanges")
    
    query = from b in MessagingExchangeBroker,
      where: b.messaging_exchange_id == ^exchange.id,
      select: b
    connections = Repo.all(query)
    assert connections != nil
    assert length(connections) == 1
    exchange_broker = List.first(connections)
    
    assert exchange_broker != nil
    assert exchange_broker.id != nil
    assert exchange_broker.messaging_broker_id == broker.id
    assert exchange_broker.messaging_exchange_id == exchange.id
  end

  test "create_broker_restriction - bad request" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    Repo.insert(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :post, "/messaging/exchanges/#{exchange.id}/brokers", %{})
    assert conn.status == 400
  end

  test "create_broker_restriction - conflict" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    Repo.insert(MessagingExchangeBroker.new(%{
      "messaging_broker_id" => broker.id,
      "messaging_exchange_id" => exchange.id
      }))

    conn = call(Router, :post, "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    })
    assert conn.status == 409
  end

  test "create_broker_restriction - internal server error" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert, fn _ -> raise "bad news bears" end)

    conn = call(Router, :post, "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    })
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "get_broker_restrictions - success" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    Repo.insert(MessagingExchangeBroker.new(%{
      "messaging_broker_id" => broker.id,
      "messaging_exchange_id" => exchange.id
      }))

    conn = call(Router, :get, "/messaging/exchanges/#{exchange.id}/brokers", %{})
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_exchange_broker = List.first(body)
    assert returned_exchange_broker != nil
    assert returned_exchange_broker["id"] != nil
    assert returned_exchange_broker["messaging_broker_id"] == broker.id
    assert returned_exchange_broker["messaging_exchange_id"] == exchange.id    
  end

  test "get_broker_restrictions - not found" do
    conn = call(Router, :get, "/messaging/exchanges/1234567980/brokers", %{})
    assert conn.status == 404
  end

  test "destroy_broker_restrictions - success" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = call(Router, :delete, "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    })
    assert conn.status == 204
    
    query = from b in MessagingExchangeBroker,
      where: b.messaging_exchange_id == ^exchange.id,
      select: b
    connections = Repo.all(query)
    assert connections != nil
    assert length(connections) == 0
  end

  test "get_broker_restrictions - not found 2" do
    conn = call(Router, :delete, "/messaging/exchanges/1234567980/brokers", %{})
    assert conn.status == 404
  end

  test "show_clusters - success" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    params = %{
      etcd_token: "123abc",
      messaging_exchange_id: exchange.id
    }
    cluster = Repo.insert(Ecto.Changeset.cast(%EtcdCluster{}, params, ~w(etcd_token), ~w(messaging_exchange_id)))

    conn = call(Router, :get, "/messaging/exchanges/#{exchange.id}/clusters", %{})
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_cluster = List.first(body)
    assert returned_cluster != nil
    assert returned_cluster["id"] == cluster.id
    assert returned_cluster["messaging_exchange_id"] == exchange.id
  end

  test "show_clusters - success build clusters" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    params = %{
      etcd_token: "123abc",
      messaging_exchange_id: exchange.id,
      allow_docker_builds: true
    }
    cluster = Repo.insert(Ecto.Changeset.cast(%EtcdCluster{}, params, ~w(etcd_token), ~w(allow_docker_builds messaging_exchange_id)))

    conn = call(Router, :get, "/messaging/exchanges/#{exchange.id}/clusters?allow_docker_builds=true", %{})
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_cluster = List.first(body)
    assert returned_cluster != nil
    assert returned_cluster["id"] == cluster.id
    assert returned_cluster["messaging_exchange_id"] == exchange.id
  end

  test "show_clusters - success found no build clusters" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    params = %{
      etcd_token: "123abc",
      messaging_exchange_id: exchange.id,
      allow_docker_builds: true
    }
    Repo.insert(Ecto.Changeset.cast(%EtcdCluster{}, params, ~w(etcd_token), ~w(allow_docker_builds messaging_exchange_id)))

    conn = call(Router, :get, "/messaging/exchanges/#{exchange.id}/clusters?allow_docker_builds=false", %{})
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 0
  end

  test "show_clusters - none associated" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    conn = call(Router, :get, "/messaging/exchanges/#{exchange.id}/clusters", %{})
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 0
  end

  test "show_clusters - not found" do
    conn = call(Router, :get, "/messaging/exchanges/1234567980/clusters", %{})
    assert conn.status == 404
  end
end