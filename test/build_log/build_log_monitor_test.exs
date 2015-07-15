defmodule OpenAperture.ManagerTest do
  use ExUnit.Case

  alias OpenAperture.Manager.RoutingKey
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Queries.MessagingBroker, as: MessagingBrokerQuery
  alias OpenAperture.Manager.DB.Models.MessagingExchange, as: MessagingExchangeModel
  alias OpenAperture.Manager.DB.Models.MessagingBroker, as: MessagingBrokerModel
  alias OpenAperture.Manager.BuildLogMonitor
  alias OpenAperture.Manager.Controllers.MessagingBrokers
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.Queue
  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.ConnectionOptions
  alias OpenAperture.Messaging.AMQP.ConnectionPools
  alias OpenAperture.Messaging.AMQP.ConnectionPool

  test "init" do
  	:meck.new(RoutingKey, [:passthrough])
    :meck.expect(RoutingKey, :build_hierarchy, fn _, _, _ -> {"a:b:c", %{name: "root_exchange_name"}} end)
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :get, fn type, _ ->
                        case type do
                          MessagingExchangeModel ->
                            %{name: "my_exchange_name", failover_exchange_id: 1}
                          MessagingBrokerModel ->
                            %{name: "my_broker_name", failover_broker_id: 1}
                        end
  										end)
    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build_with_exchange, fn queue_name, exchange_model, _, [routing_key: routing_key] ->
                      assert String.starts_with?(queue_name, "a:b:c.manager.build_logs.")
                      assert exchange_model.name == "my_exchange_name"
                      assert exchange_model.failover_name == "my_exchange_name"
                      assert routing_key == "a:b:c.build_logs"
                      %Queue{name: "my_queue_name"}
                    end)
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
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> :pool end)
    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, exchange, queue, _ ->
                          assert exchange.name == "my_exchange_name"
                          assert exchange.failover_name == "my_exchange_name"
                          assert queue.auto_declare == true
                          assert queue.name == "my_queue_name"
                          IO.puts "got here"
                        end)
    :meck.new(ConnectionOptions, [:passthroug])
    :meck.expect(ConnectionOptions, :type, fn options ->
                                            assert options.id == 1234
                                            assert options.username == "un"
                                            assert options.password == "decrypted_password"
                                            assert options.host == "myhost.co"
                                            assert options.port == 12345
                                            assert options.virtual_host == "myvhost"                                            
                                           end)

    BuildLogMonitor.init(:ok)

  after
    :meck.unload(ConnectionOptions)
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
    :meck.unload(MessagingBrokers)
    :meck.unload(ConnectionOptionsResolver)
    :meck.unload(MessagingBrokerQuery)
    :meck.unload(QueueBuilder)
    :meck.unload(RoutingKey)
  	:meck.unload(Repo)
  end

end