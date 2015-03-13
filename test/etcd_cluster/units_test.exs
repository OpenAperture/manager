defmodule ProjectOmeletteManager.EtcdCluster.Units.Test do
  use ExUnit.Case

  import ProjectOmeletteManager.EtcdCluster.Units

  setup do
    # :meck.new(FleetApi.Unit)

    on_exit fn -> :meck.unload end
  end

  test "deploy_units -- no units" do
    assert [] == deploy_units([], "some_etcd_token")
  end

  test "deploy_units --no units and specify ports" do
    assert [] == deploy_units([], "some_etcd_token", [1, 2, 3, 4, 5])
  end

  test "deploy_units -- unit without .service suffix" do
    unit = %{"name" => "#{UUID.uuid1()}"}

    assert [] = deploy_units([unit], "some_etcd_token")
  end

  test "deploy_units -- units with create failing" do
  end
end