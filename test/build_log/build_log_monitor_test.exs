defmodule OpenAperture.Manager.BuildLogs.BuildLogMonitor do
  use ExUnit.Case

  alias OpenAperture.Manager.RoutingKey
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Queries.MessagingBroker, as: MessagingBrokerQuery
  alias OpenAperture.Manager.DB.Models.MessagingExchange, as: MessagingExchangeModel
  alias OpenAperture.Manager.DB.Models.MessagingBroker, as: MessagingBrokerModel
  alias OpenAperture.Manager.BuildLogMonitor
  alias OpenAperture.Manager.Controllers.MessagingBrokers
  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.Queue
  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.ConnectionOptions
  alias OpenAperture.Messaging.AMQP.ConnectionPools
  alias OpenAperture.Messaging.AMQP.ConnectionPool

  test "init" do
    exchange =  %OpenAperture.Messaging.AMQP.Exchange{auto_declare: false,
                   failover_name: "my_exchange_name",
                   failover_root_exchange_name: "root_exchange_name",
                   failover_routing_key: "a:b:c", name: "my_exchange_name", options: [:durable],
                   root_exchange_name: "my_exchange_name", routing_key: "my_routing_key",
                   type: :direct}

  	:meck.new(RoutingKey, [:passthrough])
    :meck.expect(RoutingKey, :build_hierarchy, fn _, _, _ -> {"a:b:c", %{name: "root_exchange_name"}} end)
    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build_with_exchange, fn queue_name, exchange_model, _, [routing_key: routing_key] ->
                      assert String.starts_with?(queue_name, "a:b:c.manager.build_logs.")
                      assert exchange_model.name == "my_exchange_name"
                      assert exchange_model.failover_name == "my_exchange_name"
                      assert routing_key == "a:b:c.build_logs"
                      %Queue{name: "my_queue_name", exchange: exchange}
                    end)
    :meck.new(MessagingBrokerQuery, [:passthrough])
    :meck.expect(MessagingBrokerQuery, :get_connections_for_broker, fn _ -> [] end)
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> :pool end)
    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, exchange, queue, _ ->
                          assert exchange.name == "my_exchange_name"
                          assert exchange.failover_name == "my_exchange_name"
                          assert queue.auto_declare == true
                          assert queue.name == "my_queue_name"
                        end)
    :meck.new(BuildLogMonitor, [:passthrough])
    :meck.expect(BuildLogMonitor, :get_exchange_model, fn _,_ ->
                 exchange
                end)
    :meck.expect(BuildLogMonitor, :get_connection_options, fn ->
                      %OpenAperture.Messaging.AMQP.ConnectionOptions{failover_heartbeat: 60,
                         failover_host: "myhost.co", failover_id: 1234,
                         failover_password: "decrypted_password", failover_port: 12345,
                         failover_username: "un", failover_virtual_host: "myvhost", heartbeat: 60,
                         host: "myhost.co", id: 1234, password: "decrypted_password", port: 12345,
                         username: "un", virtual_host: "myvhost"}
                    end)

    BuildLogMonitor.init(:ok)

  after
    :meck.unload(BuildLogMonitor)
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
    :meck.unload(MessagingBrokerQuery)
    :meck.unload(QueueBuilder)
    :meck.unload(RoutingKey)
  end

  test "get_exchange_model - success" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :get, fn _, _ -> %{name: "my_exchange_name", failover_exchange_id: 1} end)
    :meck.new(RoutingKey, [:passthrough])
    :meck.expect(RoutingKey, :build_hierarchy, fn _, _, _ -> {"a:b:c", %{name: "root_exchange_name"}} end)

    exchange_model = BuildLogMonitor.get_exchange_model("my_routing_key", %{name: "my_exchange_name", failover_exchange_id: 1})
    assert exchange_model.name == "my_exchange_name"
    assert exchange_model.failover_name == "my_exchange_name"
    assert exchange_model.routing_key == "my_routing_key"
  after
    :meck.unload(Repo)
    :meck.unload(RoutingKey)
  end

  test "get_exchange_model - failure" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :get, fn _, _ -> nil end)
    :meck.new(Configuration, [:passthrough])
    :meck.expect(Configuration, :get_current_exchange_id, fn -> 99 end)
    assert_raise RuntimeError, "Exchange 99 not found", fn -> BuildLogMonitor.get_exchange_model("my_routing_key", %{}) end
  after
    :meck.unload(Configuration)
    :meck.unload(Repo)
  end

  test "get_connection_options - success" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :get, fn _, _ -> %{name: "my_broker_name", failover_broker_id: 1} end)
    :meck.new(MessagingBrokerQuery, [:passthrough])
    :meck.expect(MessagingBrokerQuery, :get_connections_for_broker, fn _ -> [] end)
    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :resolve_connection_option_for_broker, fn _ ->
                                          %{id: 1234, 
                                            username: "un", 
                                            password: "pwd", 
                                            host: "myhost.co", 
                                            port: 12345, 
                                            virtual_host: "myvhost"}
                                          end)
    :meck.new(MessagingBrokers, [:passthrough])
    :meck.expect(MessagingBrokers, :decrypt_password, fn _ -> "decrypted_password" end)
    connection_options = BuildLogMonitor.get_connection_options
    assert connection_options.id == 1234
    assert connection_options.username == "un"
    assert connection_options.password == "decrypted_password"
    assert connection_options.host == "myhost.co"
    assert connection_options.port == 12345
    assert connection_options.virtual_host == "myvhost"   
  after
    :meck.unload(Repo)
    :meck.unload(MessagingBrokerQuery) 
    :meck.unload(ConnectionOptionsResolver) 
    :meck.unload(MessagingBrokers)
  end

  test "get_connection_options - failure" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :get, fn _, _ -> nil end)
    :meck.new(Configuration, [:passthrough])
    :meck.expect(Configuration, :get_current_broker_id, fn -> 999 end)
    assert_raise RuntimeError, "Broker 999 not found", &BuildLogMonitor.get_connection_options/0
  after
    :meck.unload(Configuration)
    :meck.unload(Repo)
  end

end