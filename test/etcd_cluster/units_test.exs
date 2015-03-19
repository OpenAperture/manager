defmodule ProjectOmeletteManager.EtcdCluster.Units.Test do
  use ExUnit.Case

  import ProjectOmeletteManager.EtcdCluster.Units

  alias ProjectOmeletteManager.SystemdUnit

  setup do
    :meck.new(FleetApi.Etcd)
    :meck.new(SystemdUnit, [:passthrough])

    on_exit fn -> :meck.unload end
  end

  test "deploy_units -- no units" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, []})

    assert [] == deploy_units([], "some_etcd_token")
  end

  test "deploy_units --no units and specify ports" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, []})

    assert [] == deploy_units([], "some_etcd_token", [1, 2, 3, 4, 5])
  end

  test "deploy_units -- unit without .service suffix" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, []})

    fleet_unit = %FleetApi.Unit{name: "#{UUID.uuid1()}"}

    assert [] = deploy_units([fleet_unit], "some_etcd_token")
  end

  test "deploy_units -- units with create failing" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, []})
    :meck.expect(SystemdUnit, :create, 1, {:error, "bad news bears"})

    fleet_unit_1 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}
    fleet_unit_2 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}

    assert [] = deploy_units([fleet_unit_1, fleet_unit_2], "some_etcd_token")
  end

  test "deploy_units - units with spinup failing" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, []})
    :meck.expect(SystemdUnit, :create, 1, {:ok, :some_pid})
    :meck.expect(SystemdUnit, :spin_up_unit, 2, false)

    fleet_unit_1 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}
    fleet_unit_2 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}

    assert [] = deploy_units([fleet_unit_1, fleet_unit_2], "some_etcd_token")
  end  

  test "deploy_units - success" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{}]})
    :meck.expect(SystemdUnit, :create, 1, {:ok, :some_pid})
    :meck.expect(SystemdUnit, :spin_up_unit, 2, true)

    fleet_unit_1 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}
    fleet_unit_2 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}

    assert [:some_pid] == deploy_units([fleet_unit_1, fleet_unit_2], "some_etcd_token")
  end  

  test "deploy_units - success with provided ports" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{}]})
    :meck.expect(SystemdUnit, :create, 1, {:ok, :some_pid})
    :meck.expect(SystemdUnit, :spin_up_unit, 2, true)

    fleet_unit_1 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}
    fleet_unit_2 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}

    assert [:some_pid, :some_pid] == deploy_units([fleet_unit_1, fleet_unit_2], "some_etcd_token", [12345, 67890])
  end  

  test "deploy_units - success with template options" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{}]})
    :meck.expect(SystemdUnit, :create, 1, {:ok, :some_pid})
    :meck.expect(SystemdUnit, :spin_up_unit, 2, true)

    fleet_unit_1 = %FleetApi.Unit{
      name: "#{UUID.uuid1()}.service",
      options: [%FleetApi.UnitOption{value: "<%= dst_port %>"}]}
    fleet_unit_2 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}

    assert [:some_pid, :some_pid] == deploy_units([fleet_unit_1, fleet_unit_2], "some_etcd_token", [12345, 67890])
  end    

  test "deploy_units - teardown previous units" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, [%FleetApi.Unit{name: "test_unit"}]})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{}]})
    :meck.expect(SystemdUnit, :create, 1, {:ok, :some_pid})
    :meck.expect(SystemdUnit, :spin_up_unit, 2, true)
    :meck.expect(SystemdUnit, :tear_down_unit, 2, true)

    fleet_unit_1 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}
    fleet_unit_2 = %FleetApi.Unit{name: "#{UUID.uuid1()}.service"}

    assert [:some_pid] == deploy_units([fleet_unit_1, fleet_unit_2], "some_etcd_token")
  end 
end