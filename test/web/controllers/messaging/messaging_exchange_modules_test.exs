defmodule OpenAperture.Manager.Controllers.MessagingExchangeModulesTest do
  use ExUnit.Case
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingExchangeModule
  alias OpenAperture.Manager.Repo

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
      Repo.delete_all(MessagingExchangeModule)
      Repo.delete_all(MessagingExchange)
    end
  end

  @endpoint OpenAperture.Manager.Endpoint

  test "index - invalid exchange" do
    conn = get conn(), "/messaging/exchanges/1234567890/modules"

    assert conn.status == 404
  end

  test "index - valid exchange no modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/modules"
  
    assert conn.status == 200

    returned_modules = Poison.decode!(conn.resp_body)
    assert returned_modules != nil
    assert returned_modules == []
  end

  test "index - valid exchange with modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    module = Repo.insert(MessagingExchangeModule.new(%{
      messaging_exchange_id: exchange.id,
      hostname: "#{UUID.uuid1()}",
      type: "builder",
      status: "active",
      workload: "[]",
    }))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/modules"
    
    assert conn.status == 200

    returned_modules = Poison.decode!(conn.resp_body)
    assert returned_modules != nil
    assert length(returned_modules) == 1
    
    returned_module = List.first(returned_modules)
    assert returned_module != nil
    assert returned_module["messaging_exchange_id"] == exchange.id
    assert returned_module["hostname"] == module.hostname
    assert returned_module["type"] == module.type
    assert returned_module["status"] == module.status
    assert returned_module["workload"] == []
  end

  test "show - invalid exchange" do
    conn = get conn(), "/messaging/exchanges/1234567890/modules/badnewsbears"
    
    assert conn.status == 404
  end

  test "show - valid exchange no modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/modules/badnewsbears"
    
    assert conn.status == 404
  end

  test "show - valid exchange with modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    module = Repo.insert(MessagingExchangeModule.new(%{
      messaging_exchange_id: exchange.id,
      hostname: "#{UUID.uuid1()}",
      type: "builder",
      status: "active",
      workload: "[]",
    }))

    conn = get conn(), "/messaging/exchanges/#{exchange.id}/modules/#{module.hostname}"
    
    assert conn.status == 200

    returned_module = Poison.decode!(conn.resp_body)
    assert returned_module != nil
    assert returned_module["messaging_exchange_id"] == exchange.id
    assert returned_module["hostname"] == module.hostname
    assert returned_module["type"] == module.type
    assert returned_module["status"] == module.status
    assert returned_module["workload"] == []
  end  

  test "destroy - invalid exchange" do
    conn = delete conn(), "/messaging/exchanges/1234567890/modules/badnewsbears"
    assert conn.status == 404
  end

  test "destroy - valid exchange no modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = delete conn(), "/messaging/exchanges/#{exchange.id}/modules/badnewsbears"
    assert conn.status == 404
  end

  test "destroy - valid exchange with modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    module = Repo.insert(MessagingExchangeModule.new(%{
      messaging_exchange_id: exchange.id,
      hostname: "#{UUID.uuid1()}",
      type: "builder",
      status: "active",
      workload: "[]",
    }))

    conn = delete conn(), "/messaging/exchanges/#{exchange.id}/modules/#{module.hostname}"
    assert conn.status == 204
  end  

  test "create - invalid exchange" do
    conn = post conn(), "/messaging/exchanges/1234567890/modules"
    assert conn.status == 404
  end

  test "create - valid exchange no modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    conn = post conn(), "/messaging/exchanges/#{exchange.id}/modules"
    assert conn.status == 400
  end

  test "create - valid exchange with modules" do
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    module_params = %{
      hostname: "#{UUID.uuid1()}",
      type: "builder",
      status: "active",
      workload: "[]",
    }

    conn = post conn(), "/messaging/exchanges/#{exchange.id}/modules", module_params
    assert conn.status == 201

    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/modules")
  end    
end