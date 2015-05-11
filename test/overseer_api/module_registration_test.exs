defmodule OpenAperture.Manager.OverseerApi.ModuleRegistrationTest do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.OverseerApi.ModuleRegistration
  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Manager.DB.Models.MessagingExchangeModule  

  alias OpenAperture.Manager.Repo

  setup do
    System.put_env("HOSTNAME", "123abc")

    on_exit fn -> 
      Repo.delete_all(MessagingExchangeModule)
      Repo.delete_all(MessagingExchange)
    end
  end

  #===============================
  # register_module tests

  test "register_module - success" do 
    exchange = Repo.insert(MessagingExchange.new(%{name: "#{UUID.uuid1()}"}))

    module = %{
      hostname: System.get_env("HOSTNAME"),
      messaging_exchange_id: exchange.id,
      type: :test,
      status: :active,
      workload: []      
    }
    assert ModuleRegistration.register_module(module) == true
  end

  test "register_module - failure" do 
    module = %{
      type: :test,
      status: :active,
      workload: []      
    }
    assert ModuleRegistration.register_module(module) == true
  end  
end
