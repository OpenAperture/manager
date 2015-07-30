defmodule OpenAperture.Manager.Controllers.MessagingExchangesTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.EtcdCluster

  import Ecto.Query

  setup do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn ->
      :meck.unload
      Repo.delete_all(MessagingExchangeBroker)
      Repo.delete_all(MessagingBroker)
      Repo.delete_all(EtcdCluster)
      Repo.delete_all(SystemComponent)
      Repo.delete_all(MessagingExchange)
    end
  end

  @endpoint OpenAperture.Manager.Endpoint

  test "index - no exchanges" do
    conn = get conn(), "/messaging/exchanges"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index - exchanges" do
    changeset = MessagingExchange.new(%{name: "#{UUID.uuid1()}"})
    exchange = Repo.insert!(changeset)

    conn = get conn(), "/messaging/exchanges"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_exchange = List.first(body)
    assert returned_exchange != nil
    assert returned_exchange["id"] == exchange.id
    assert returned_exchange["name"] == exchange.name
  end

  test "index - hierarchy of exchanges" do
    changeset = MessagingExchange.new(%{
      name: "#{UUID.uuid1()}",
      routing_key_fragment: "provider"
    })
    exchange = Repo.insert!(changeset)

    changeset = MessagingExchange.new(%{
      name: "#{UUID.uuid1()}",
      failover_exchange_id: exchange.id,
      parent_exchange_id: exchange.id,
      routing_key_fragment: "region"
    })
    child_exchange = Repo.insert!(changeset)

    conn = get conn(), "/messaging/exchanges"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 2
    Enum.reduce body, nil, fn(returned_exchange, _errors) ->
      cond do
        returned_exchange == nil -> 
          assert returned_exchange != nil
        returned_exchange["id"] == exchange.id ->
          assert returned_exchange["id"] == exchange.id
          assert returned_exchange["name"] == exchange.name
          assert returned_exchange["routing_key_fragment"] == exchange.routing_key_fragment
          assert returned_exchange["routing_key"] == exchange.routing_key_fragment
          assert returned_exchange["root_exchange_name"] == exchange.name
        returned_exchange["id"] == child_exchange.id ->
          assert returned_exchange["id"] == child_exchange.id
          assert returned_exchange["name"] == child_exchange.name
          assert returned_exchange["routing_key_fragment"] == child_exchange.routing_key_fragment
          assert returned_exchange["routing_key"] == "#{exchange.routing_key_fragment}.#{child_exchange.routing_key_fragment}"
          assert returned_exchange["root_exchange_name"] == exchange.name          
        true -> assert true == false
      end
    end
  end

  test "show - invalid exchange" do
    conn = get conn(), "/messaging/exchanges/0123456789"
    assert conn.status == 404
  end

  test "show - valid exchange" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}"
    assert conn.status == 200

    returned_exchange = Poison.decode!(conn.resp_body)
    assert returned_exchange != nil
    assert returned_exchange["id"] == exchange.id
    assert returned_exchange["name"] == exchange.name
  end

  test "show - valid exchange in hierarchy" do
    changeset = MessagingExchange.new(%{
      name: "#{UUID.uuid1()}",
      routing_key_fragment: "provider"
    })
    exchange = Repo.insert!(changeset)

    changeset = MessagingExchange.new(%{
      name: "#{UUID.uuid1()}",
      failover_exchange_id: exchange.id,
      parent_exchange_id: exchange.id,
      routing_key_fragment: "region"
    })
    child_exchange = Repo.insert!(changeset)
    conn = get conn(), "/messaging/exchanges/#{child_exchange.id}"
    assert conn.status == 200

    returned_exchange = Poison.decode!(conn.resp_body)
    assert returned_exchange != nil
    assert returned_exchange["id"] == child_exchange.id
    assert returned_exchange["name"] == child_exchange.name
    assert returned_exchange["routing_key_fragment"] == child_exchange.routing_key_fragment
    assert returned_exchange["routing_key"] == "#{exchange.routing_key_fragment}.#{child_exchange.routing_key_fragment}"
    assert returned_exchange["root_exchange_name"] == exchange.name
  end

  test "create - conflict" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = post conn(), "/messaging/exchanges", %{"name" => exchange.name}
    assert conn.status == 409
  end

  test "create - bad request" do
    conn = post conn(), "/messaging/exchanges", %{}
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert!, fn _ -> raise "bad news bears" end)

    conn = post conn(), "/messaging/exchanges", %{"name" => "#{UUID.uuid1()}"}
    
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success" do
    name = "#{UUID.uuid1()}"
    conn = post conn(), "/messaging/exchanges", %{"name" => name}
    
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
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    exchange2 = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = put conn(), "/messaging/exchanges/#{exchange.id}", %{"name" => exchange2.name}
    assert conn.status == 409
  end

  test "update - bad request" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = put conn(), "/messaging/exchanges/#{exchange.id}", %{}
    assert conn.status == 400
    assert conn.resp_body != nil
  end

  test "update - internal server error" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :update!, fn _ -> raise "bad news bears" end)

    conn = put conn(), "/messaging/exchanges/#{exchange.id}", %{"name" => "#{UUID.uuid1()}"}
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "update - success" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    name = "#{UUID.uuid1()}"
    conn = put conn(), "/messaging/exchanges/#{exchange.id}", %{"name" => name}
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
    conn = delete conn(), "/messaging/exchanges/0123456789"
    assert conn.status == 404
  end

  test "destroy - valid exchange" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = delete conn(), "/messaging/exchanges/#{exchange.id}"
    assert conn.status == 204

    assert Repo.get(MessagingExchange, exchange.id) == nil
  end

  test "create_broker_restriction - success" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    conn = post conn(), "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    }
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
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    conn = post conn(), "/messaging/exchanges/#{exchange.id}/brokers", %{}
    assert conn.status == 400
  end

  test "create_broker_restriction - conflict" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    Repo.insert!(MessagingExchangeBroker.new(%{
      "messaging_broker_id" => broker.id,
      "messaging_exchange_id" => exchange.id
      }))
    conn = post conn(), "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    }
    assert conn.status == 409
  end

  test "create_broker_restriction - internal server error" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))

    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert!, fn _ -> raise "bad news bears" end)
    conn = post conn(), "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    }
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "get_broker_restrictions - success" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    Repo.insert!(MessagingExchangeBroker.new(%{
      "messaging_broker_id" => broker.id,
      "messaging_exchange_id" => exchange.id
      }))
    conn = get conn(), "/messaging/exchanges/#{exchange.id}/brokers", %{}
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
    conn = get conn(), "/messaging/exchanges/0123456789/brokers", %{}
    
    assert conn.status == 404
  end

  test "destroy_broker_restrictions - success" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    broker = Repo.insert!(MessagingBroker.new(%{name: "#{UUID.uuid1()}"}))
    conn = delete conn(), "/messaging/exchanges/#{exchange.id}/brokers", %{
      "messaging_broker_id" => broker.id
    }
    assert conn.status == 204
    
    query = from b in MessagingExchangeBroker,
      where: b.messaging_exchange_id == ^exchange.id,
      select: b
    connections = Repo.all(query)
    assert connections != nil
    assert length(connections) == 0
  end

  test "get_broker_restrictions - not found 2" do
    conn = delete conn(), "/messaging/exchanges/0123456789/brokers", %{}
    assert conn.status == 404
  end

  test "show_clusters - success" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    params = %{
      etcd_token: "123abc",
      messaging_exchange_id: exchange.id
    }
    cluster = Repo.insert!(Ecto.Changeset.cast(%EtcdCluster{}, params, ~w(etcd_token), ~w(messaging_exchange_id)))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/clusters", %{}
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_cluster = List.first(body)
    assert returned_cluster != nil
    assert returned_cluster["id"] == cluster.id
    assert returned_cluster["messaging_exchange_id"] == exchange.id
  end

  test "show_clusters - success build clusters" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    params = %{
      etcd_token: "123abc",
      messaging_exchange_id: exchange.id,
      allow_docker_builds: true
    }
    cluster = Repo.insert!(Ecto.Changeset.cast(%EtcdCluster{}, params, ~w(etcd_token), ~w(allow_docker_builds messaging_exchange_id)))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/clusters?allow_docker_builds=true", %{}
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
    returned_cluster = List.first(body)
    assert returned_cluster != nil
    assert returned_cluster["id"] == cluster.id
    assert returned_cluster["messaging_exchange_id"] == exchange.id
  end

  test "show_clusters - success found no build clusters" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    params = %{
      etcd_token: "123abc",
      messaging_exchange_id: exchange.id,
      allow_docker_builds: true
    }
    Repo.insert!(Ecto.Changeset.cast(%EtcdCluster{}, params, ~w(etcd_token), ~w(allow_docker_builds messaging_exchange_id)))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/clusters?allow_docker_builds=false", %{}
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 0
  end

  test "show_clusters - none associated" do
    exchange = Repo.insert!(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))
    conn = get conn(), "/messaging/exchanges/#{exchange.id}/clusters", %{}
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 0
  end

  test "show_clusters - not found" do
    conn = get conn(), "/messaging/exchanges/1234567980/clusters", %{}
    assert conn.status == 404
  end

  # =============================
  # show_components tests

  test "show_components - not found" do
    conn = get conn(), "/messaging/exchanges/1234567890/system_components"
    assert conn.status == 404
  end

  test "show_components - no components" do
    changeset = MessagingExchange.new(%{name: "#{UUID.uuid1()}"})
    exchange = Repo.insert!(changeset)

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/system_components"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 0
  end  

  test "show_components - components" do
    changeset = MessagingExchange.new(%{name: "#{UUID.uuid1()}"})
    exchange = Repo.insert!(changeset)

    component = Repo.insert!(SystemComponent.new(%{messaging_exchange_id: exchange.id, type: "test", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))
    component2 = Repo.insert!(SystemComponent.new(%{messaging_exchange_id: exchange.id, type: "test2", source_repo: "https://github.com/test/test.git", source_repo_git_ref: "123abc", upgrade_strategy: "manual", deployment_repo: "https://github.com/test/test.git", deployment_repo_git_ref: "123abc"}))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/system_components"
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 2
    assert Enum.reduce body, true, fn (returned_component, success) ->
      if success do
        cond do 
          returned_component["id"] == component.id -> true
          returned_component["id"] == component2.id -> true
          true -> false
        end
      else
        success
      end
    end
  end  
end