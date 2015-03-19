defmodule ProjectOmeletteManager.SystemdUnit.Test do
  use ExUnit.Case

  import ProjectOmeletteManager.SystemdUnit
  alias ProjectOmeletteManager.SystemdUnit

  setup do
    :meck.new(File, [:unstick, :passthrough])
    :meck.new(System, [:unstick, :passthrough])
    :meck.new(EEx, [:unstick, :passthrough])

    :meck.new(FleetApi)
    :meck.new(FleetApi.Etcd)

    on_exit fn -> :meck.unload end
  end

  test "set_etcd_token success" do
    unit_pid = create!(%SystemdUnit{})
    assert :ok == set_etcd_token(unit_pid, "123abc")
  end

  test "set_assigned_port success" do
    unit_pid = create!(%SystemdUnit{})

    assert :ok == set_assigned_port(unit_pid, 45000)
  end

  test "get_assigned_port success" do
    unit_pid = create!(%SystemdUnit{})
    set_assigned_port(unit_pid, 45000)

    assert 45000 == get_assigned_port(unit_pid)
  end

  test "refresh success" do
    unit_uuid = "#{UUID.uuid1()}"
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :get_unit, fn _, _ -> {:ok, %FleetApi.Unit{name: unit_uuid}} end)

    unit = create!(%SystemdUnit{})
    refresh(unit)
    assert get_unit_name(unit) == unit_uuid
  end

  test "refresh failed - invalid data" do
    unit_uuid = "#{UUID.uuid1()}"
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :get_unit, fn _, _ -> {:ok, %FleetApi.Unit{}} end)

    fleet_unit = %FleetApi.Unit{name: unit_uuid}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    refresh(unit)
    assert get_unit_name(unit) == unit_uuid
  end

  test "refresh failure" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :get_unit, fn _, _ -> {:ok, %FleetApi.Unit{name: nil}} end)
    unit_pid = create!(%SystemdUnit{})

    assert :error == refresh(unit_pid)
  end

  test "get_unit_name success" do
    fleet_unit = %FleetApi.Unit{name: "test name"}
    unit_pid = create!(%SystemdUnit{fleet_unit: fleet_unit})

    assert "test name" == get_unit_name(unit_pid)
  end

  test "get_machine_id success" do
    fleet_unit = %FleetApi.Unit{machineID: "test machine id"}
    unit_pid = create!(%SystemdUnit{fleet_unit: fleet_unit})

    assert "test machine id" == get_machine_id(unit_pid)
  end

  test "is_launched? success" do
    fleet_unit = %FleetApi.Unit{currentState: "launched"}
    unit_pid = create!(%{fleet_unit: fleet_unit})

    assert is_launched?(unit_pid)
  end

  test "is_launched? -- not launched" do
    fleet_unit = %FleetApi.Unit{currentState: "inactive"}
    unit_pid = create!(%{fleet_unit: fleet_unit})

    assert {false, "inactive"} == is_launched?(unit_pid)
  end

  test "is_active? - invalid response" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_unit_states, fn _ -> {:ok, nil} end)

    unit = create!(%SystemdUnit{})
    assert is_active?(unit) == {false, nil, nil, nil}
  end

  test "is_active? - unit state missing" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_unit_states, fn _ -> {:ok, []} end)

    fleet_unit = %FleetApi.Unit{name: "test"}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert is_active?(unit) == {false, nil, nil, nil}
  end 

  test "is_active? - systemdActiveState inactive" do
    unit_name = "#{UUID.uuid1()}"
    state = %FleetApi.UnitState{
      name: unit_name,
      systemdActiveState: "inactive",
      systemdLoadState: "loaded",
      systemdSubState: "failed"
    }
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_unit_states, fn _ -> {:ok, [state]} end)

    fleet_unit = %FleetApi.Unit{name: unit_name}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert is_active?(unit) == {false, "inactive", "loaded", "failed"}
  end  

  test "is_active? - systemdActiveState active" do
    unit_name = "#{UUID.uuid1()}"
    state = %FleetApi.UnitState{
      name: unit_name,
      systemdActiveState: "active",
      systemdLoadState: "loaded",
      systemdSubState: "failed"
    }
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_unit_states, fn _ -> {:ok, [state]} end)

    fleet_unit = %FleetApi.Unit{name: unit_name}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert is_active?(unit) == true
  end 

  test "spin_up_unit - unknown response" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :set_unit, fn _, _, _ -> {:error, %FleetApi.Error{code: 500, message: "bad news bears"}} end)

    fleet_unit = %FleetApi.Unit{name: "#{UUID.uuid1()}"}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert spin_up_unit(unit) == false
  end  

  test "spin_up_unit - success" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :set_unit, fn _, _, _ -> :ok end)

    fleet_unit = %FleetApi.Unit{name: "#{UUID.uuid1()}"}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert spin_up_unit(unit) == true
  end   

  test "tear_down_unit - unknown response" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :delete_unit, fn _, _ -> {:error, %FleetApi.Error{code: 500, message: "bad news bears"}} end)

    fleet_unit = %FleetApi.Unit{name: "#{UUID.uuid1()}"}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert tear_down_unit(unit) == :ok
  end  

  test "teardown_unit - 204 response" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :delete_unit, fn _, _ -> :ok end)
    :meck.expect(FleetApi.Etcd, :get_unit, fn _, _ -> {:error, %FleetApi.Error{code: 404}} end)

    unit_name = "#{UUID.uuid1()}"
    state = %FleetApi.UnitState{
      name: unit_name,
      systemdActiveState: "active",
      systemdLoadState: "loaded",
      systemdSubState: "running"
    }
    :meck.expect(FleetApi.Etcd, :list_unit_states, fn _ -> {:ok, [state]} end)

    fleet_unit = %FleetApi.Unit{name: "#{UUID.uuid1()}"}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert tear_down_unit(unit) == :ok
  end   

  test "teardown_unit - 201 response" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :delete_unit, fn _, _ -> :ok end)
    :meck.expect(FleetApi.Etcd, :get_unit, fn _, _ -> {:error, %FleetApi.Error{code: 404}} end)

    unit_name = "#{UUID.uuid1()}"
    state = %FleetApi.UnitState{
      name: unit_name,
      systemdActiveState: "active",
      systemdLoadState: "loaded",
      systemdSubState: "running"
    }
    :meck.expect(FleetApi.Etcd, :list_unit_states, fn _ -> {:ok, [state]} end)

    fleet_unit = %FleetApi.Unit{name: "#{UUID.uuid1()}"}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    assert tear_down_unit(unit) == :ok
  end  

  test "get_journal - no machineID and no hosts" do
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, fn _ -> {:ok, []} end)

    unit = create!(%SystemdUnit{})
    {result, stdout, stderr} = get_journal(unit)
    assert result == :error
    assert stdout != nil
    assert stderr != nil
  end

  test "get_journal - no machineID and host success" do
    :meck.expect(File, :mkdir_p, fn _ -> true end)
    :meck.expect(File, :write!, fn _, _ -> true end)
    :meck.expect(File, :rm_rf, fn _ -> true end)
    :meck.expect(File, :exists?, fn _ -> false end)
    
    :meck.expect(System, :cmd, fn _, _, _ -> {"", 0} end)
    :meck.expect(System, :cwd!, fn -> "" end)

    :meck.expect(EEx, :eval_file, fn _, _ -> "" end)
    
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, fn _ -> {:ok, [%FleetApi.Machine{}]} end)

    unit = create!(%SystemdUnit{})
    {result, stdout, stderr} = get_journal(unit)
    assert result == :ok
    assert stdout != nil
    assert stderr != nil
  end  

  test "get_journal - no machineID and host failure" do
    :meck.expect(File, :mkdir_p, fn _ -> true end)
    :meck.expect(File, :write!, fn _, _ -> true end)
    :meck.expect(File, :rm_rf, fn _ -> true end)
    :meck.expect(File, :exists?, fn _ -> false end)
    
    :meck.expect(System, :cmd, fn _, _, _ -> {"", 128} end)
    :meck.expect(System, :cwd!, fn -> "" end)

    :meck.expect(EEx, :eval_file, fn _, _ -> "" end)
    
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, fn _ -> {:ok, [%FleetApi.Machine{}]} end)

    unit = create!(%SystemdUnit{})
    {result, stdout, stderr} = get_journal(unit)
    assert result == :error
    assert stdout != nil
    assert stderr != nil
  end   

  test "get_journal - machineID and host success" do
    :meck.expect(File, :mkdir_p, fn _ -> true end)
    :meck.expect(File, :write!, fn _, _ -> true end)
    :meck.expect(File, :rm_rf, fn _ -> true end)
    :meck.expect(File, :exists?, fn _ -> false end)
    
    :meck.expect(System, :cmd, fn _, _, _ -> {"", 0} end)
    :meck.expect(System, :cwd!, fn -> "" end)

    :meck.expect(EEx, :eval_file, fn _, _ -> "" end)
    
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})

    machine_id = "#{UUID.uuid1()}"
    machine = %FleetApi.Machine{id: machine_id}
    :meck.expect(FleetApi.Etcd, :list_machines, fn _ -> {:ok, [machine]} end)

    fleet_unit = %FleetApi.Unit{machineID: machine_id}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    {result, stdout, stderr} = get_journal(unit)
    assert result == :ok
    assert stdout != nil
    assert stderr != nil
  end  

  test "get_journal - machineID and host failure" do
    :meck.expect(File, :mkdir_p, fn _ -> true end)
    :meck.expect(File, :write!, fn _, _ -> true end)
    :meck.expect(File, :rm_rf, fn _ -> true end)
    :meck.expect(File, :exists?, fn _ -> false end)
    
    :meck.expect(System, :cmd, fn _, _, _ -> {"", 128} end)
    :meck.expect(System, :cwd!, fn -> "" end)

    :meck.expect(EEx, :eval_file, fn _, _ -> "" end)

    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    
    machine_id = "#{UUID.uuid1()}"
    machine = %FleetApi.Machine{id: machine_id}
    :meck.expect(FleetApi.Etcd, :list_machines, fn _ -> {:ok, [machine]} end)

    fleet_unit = %FleetApi.Unit{machineID: machine_id}
    unit = create!(%SystemdUnit{fleet_unit: fleet_unit})
    {result, stdout, stderr} = get_journal(unit)
    assert result == :error
    assert stdout != nil
    assert stderr != nil
  end
end