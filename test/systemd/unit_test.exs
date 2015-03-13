defmodule ProjectOmeletteManager.Systemd.Unit.Test do
  use ExUnit.Case

  import ProjectOmeletteManager.Systemd.Unit

  setup do
    # :meck.new(FleetApi.Unit)

    on_exit fn -> :meck.unload end
  end

  test "set_etcd_token success" do
    unit_pid = create!(%{})
    assert :ok == set_etcd_token(unit_pid, "123abc")
  end

  test "set_assigned_port success" do
    unit_pid = create!(%{})

    assert :ok == set_assigned_port(unit_pid, 45000)
  end

  test "get_assigned_port success" do
    unit_pid = create!(%{})
    set_assigned_port(unit_pid, 45000)

    assert 45000 == get_assigned_port(unit_pid)
  end

  # test "refresh success" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   unit_uuid = "#{UUID.uuid1()}"
  #   :meck.expect(FleetApi.Unit, :get_unit!, fn token, unit_name -> Map.put(%{}, "name", unit_uuid) end)

  #   unit = SystemdUnit.create!(%{})
  #   SystemdUnit.refresh(unit)
  #   assert SystemdUnit.get_unit_name(unit) == unit_uuid
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end

  # test "refresh failed - invalid data" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   unit_uuid = "#{UUID.uuid1()}"
  #   :meck.expect(FleetApi.Unit, :get_unit!, fn token, unit_name -> %{} end)

  #   unit = SystemdUnit.create!(%{"name" => unit_uuid})
  #   SystemdUnit.refresh(unit)
  #   assert SystemdUnit.get_unit_name(unit) == unit_uuid
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end

  test "refresh failure" do
    unit_pid = create!(%{})

    assert :error == refresh(unit_pid)
  end

  test "get_unit_name success" do
    unit_pid = create!(%{"name" => "test name"})

    assert "test name" == get_unit_name(unit_pid)
  end

  test "get_machine_id success" do
    unit_pid = create!(%{"machineID" => "test machine id"})

    assert "test machine id" == get_machine_id(unit_pid)
  end

  test "is_launched? success" do
    unit_pid = create!(%{"currentState" => "launched"})

    assert is_launched?(unit_pid)
  end

  test "is_launched? -- not launched" do
    unit_pid = create!(%{"currentState" => "inactive"})

    assert {false, "inactive"} == is_launched?(unit_pid)
  end

  # test "is_active? - error" do
  #   :meck.new(FleetApi.UnitState, [:passthrough])
  #   :meck.expect(FleetApi.UnitState, :list!, fn token -> raise "bad news bears" end)

  #   unit = SystemdUnit.create!(%{})
  #   try do 
  #     assert SystemdUnit.is_active?(unit)
  #     assert true == false
  #   rescue e in _ ->
  #     assert e != nil
  #   end
  # after
  #   :meck.unload(FleetApi.UnitState)   
  # end

  # test "is_active? - invalid response" do
  #   :meck.new(FleetApi.UnitState, [:passthrough])
  #   :meck.expect(FleetApi.UnitState, :list!, fn token -> nil end)

  #   unit = SystemdUnit.create!(%{})
  #   assert SystemdUnit.is_active?(unit) == {false, nil, nil, nil}
  # after
  #   :meck.unload(FleetApi.UnitState)   
  # end

  # test "is_active? - unit state missing" do
  #   :meck.new(FleetApi.UnitState, [:passthrough])
  #   :meck.expect(FleetApi.UnitState, :list!, fn token -> [] end)

  #   unit = SystemdUnit.create!(%{})
  #   assert SystemdUnit.is_active?(unit) == {false, nil, nil, nil}
  # after
  #   :meck.unload(FleetApi.UnitState)   
  # end 

  # test "is_active? - systemdActiveState inactive" do
  #   :meck.new(FleetApi.UnitState, [:passthrough])
  #   unit_name = "#{UUID.uuid1()}"
  #   state = %{}
  #   state = Map.put(state, "name", unit_name)
  #   state = Map.put(state, "systemdActiveState", "inactive")
  #   state = Map.put(state, "systemdLoadState", "loaded")
  #   state = Map.put(state, "systemdSubState", "failed")
  #   states = [state]
  #   :meck.expect(FleetApi.UnitState, :list!, fn token -> states end)

  #   unit = SystemdUnit.create!(Map.put(%{}, "name", unit_name))
  #   assert SystemdUnit.is_active?(unit) == {false, "inactive", "loaded", "failed"}
  # after
  #   :meck.unload(FleetApi.UnitState)   
  # end  

  # test "is_active? - systemdActiveState active" do
  #   :meck.new(FleetApi.UnitState, [:passthrough])
  #   unit_name = "#{UUID.uuid1()}"
  #   state = %{}
  #   state = Map.put(state, "name", unit_name)
  #   state = Map.put(state, "systemdActiveState", "active")
  #   state = Map.put(state, "systemdLoadState", "loaded")
  #   state = Map.put(state, "systemdSubState", "running")
  #   states = [state]
  #   :meck.expect(FleetApi.UnitState, :list!, fn token -> states end)

  #   unit = SystemdUnit.create!(Map.put(%{}, "name", unit_name))
  #   assert SystemdUnit.is_active?(unit) == true
  # after
  #   :meck.unload(FleetApi.UnitState)   
  # end 

  # test "spinup_unit - error" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :set_unit, fn unit, token -> raise "bad news bears" end)

  #   unit = SystemdUnit.create!(%{})
  #   try do 
  #     assert SystemdUnit.spinup_unit(unit)
  #     assert true == false
  #   rescue e in _ ->
  #     assert e != nil
  #   end
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end

  # test "spinup_unit - unknown response" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :set_unit, fn unit, token, options -> %FleetApi.Response{status: 500, body: "bad news bears"} end)

  #   unit = SystemdUnit.create!(%{name: "#{UUID.uuid1()}"})
  #   assert SystemdUnit.spinup_unit(unit) == false
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end  

  # test "spinup_unit - 204 response" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :set_unit, fn unit, token, options -> %FleetApi.Response{status: 204} end)

  #   unit = SystemdUnit.create!(%{name: "#{UUID.uuid1()}"})
  #   assert SystemdUnit.spinup_unit(unit) == true
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end   

  # test "spinup_unit - 201 response" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :set_unit, fn unit, token, options -> %FleetApi.Response{status: 201} end)

  #   unit = SystemdUnit.create!(%{name: "#{UUID.uuid1()}"})
  #   assert SystemdUnit.spinup_unit(unit) == true
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end 

  # test "teardown_unit - error" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :delete_unit, fn unit, token -> raise "bad news bears" end)

  #   unit = SystemdUnit.create!(%{})
  #   try do 
  #     assert SystemdUnit.teardown_unit(unit)
  #     assert true == false
  #   rescue e in _ ->
  #     assert e != nil
  #   end
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end

  # test "teardown_unit - unknown response" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :delete_unit, fn unit, token -> %FleetApi.Response{status: 500, body: "bad news bears"} end)

  #   unit = SystemdUnit.create!(%{name: "#{UUID.uuid1()}"})
  #   assert SystemdUnit.teardown_unit(unit) == :ok
  # after
  #   :meck.unload(FleetApi.Unit)   
  # end  

  # test "teardown_unit - 204 response" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :delete_unit, fn unit, token -> %FleetApi.Response{status: 204} end)
  #   :meck.expect(FleetApi.Unit, :get_unit, fn unit, token -> %FleetApi.Response{status: 404} end)

  #   :meck.new(FleetApi.UnitState, [:passthrough])
  #   unit_name = "#{UUID.uuid1()}"
  #   state = %{}
  #   state = Map.put(state, "name", unit_name)
  #   state = Map.put(state, "systemdActiveState", "active")
  #   state = Map.put(state, "systemdLoadState", "loaded")
  #   state = Map.put(state, "systemdSubState", "running")
  #   states = [state]
  #   :meck.expect(FleetApi.UnitState, :list!, fn token -> states end)

  #   unit = SystemdUnit.create!(%{name: unit_name})
  #   assert SystemdUnit.teardown_unit(unit) == :ok
  # after
  #   :meck.unload(FleetApi.Unit)   
  #   :meck.unload(FleetApi.UnitState)   
  # end   

  # test "teardown_unit - 201 response" do
  #   :meck.new(FleetApi.Unit, [:passthrough])
  #   :meck.expect(FleetApi.Unit, :delete_unit, fn unit, token -> %FleetApi.Response{status: 201} end)
  #   :meck.expect(FleetApi.Unit, :get_unit, fn unit, token -> %FleetApi.Response{status: 404} end)

  #   :meck.new(FleetApi.UnitState, [:passthrough])
  #   unit_name = "#{UUID.uuid1()}"
  #   state = %{}
  #   state = Map.put(state, "name", unit_name)
  #   state = Map.put(state, "systemdActiveState", "active")
  #   state = Map.put(state, "systemdLoadState", "loaded")
  #   state = Map.put(state, "systemdSubState", "running")
  #   states = [state]
  #   :meck.expect(FleetApi.UnitState, :list!, fn token -> states end)    

  #   unit = SystemdUnit.create!(%{name: unit_name})
  #   assert SystemdUnit.teardown_unit(unit) == :ok
  # after
  #   :meck.unload(FleetApi.Unit)   
  #   :meck.unload(FleetApi.UnitState)   
  # end  

  # test "get_journal - no machineID and no hosts" do
  #   :meck.new(FleetApi.Machine, [:passthrough])
  #   :meck.expect(FleetApi.Machine, :list!, fn token -> [] end)

  #   unit = SystemdUnit.create!(%{})
  #   {result, stdout, stderr} = SystemdUnit.get_journal(unit)
  #   assert result == :error
  #   assert stdout != nil
  #   assert stderr != nil
  # after
  #   :meck.unload(FleetApi.Machine)
  # end

  # test "get_journal - no machineID and host success" do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :mkdir_p, fn path -> true end)
  #   :meck.expect(File, :write!, fn path, contents -> true end)
  #   :meck.expect(File, :rm_rf, fn path -> true end)
  #   :meck.expect(File, :exists?, fn path -> false end)
    
  #   :meck.new(System, [:unstick])
  #   :meck.expect(System, :cmd, fn cmd, opts, opts2 -> {"", 0} end)
  #   :meck.expect(System, :cwd!, fn -> "" end)

  #   :meck.new(EEx, [:unstick])
  #   :meck.expect(EEx, :eval_file, fn path, options -> "" end)
    
  #   :meck.new(FleetApi.Machine, [:passthrough])
  #   :meck.expect(FleetApi.Machine, :list!, fn token -> [%{}] end)

  #   unit = SystemdUnit.create!(%{})
  #   {result, stdout, stderr} = SystemdUnit.get_journal(unit)
  #   assert result == :ok
  #   assert stdout != nil
  #   assert stderr != nil
  # after
  #   :meck.unload(File)
  #   :meck.unload(System)
  #   :meck.unload(EEx)
  #   :meck.unload(FleetApi.Machine)
  # end  

  # test "get_journal - no machineID and host failure" do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :mkdir_p, fn path -> true end)
  #   :meck.expect(File, :write!, fn path, contents -> true end)
  #   :meck.expect(File, :rm_rf, fn path -> true end)
  #   :meck.expect(File, :exists?, fn path -> false end)
    
  #   :meck.new(System, [:unstick])
  #   :meck.expect(System, :cmd, fn cmd, opts, opts2 -> {"", 128} end)
  #   :meck.expect(System, :cwd!, fn -> "" end)

  #   :meck.new(EEx, [:unstick])
  #   :meck.expect(EEx, :eval_file, fn path, options -> "" end)
    
  #   :meck.new(FleetApi.Machine, [:passthrough])
  #   :meck.expect(FleetApi.Machine, :list!, fn token -> [%{}] end)

  #   unit = SystemdUnit.create!(%{})
  #   {result, stdout, stderr} = SystemdUnit.get_journal(unit)
  #   assert result == :error
  #   assert stdout != nil
  #   assert stderr != nil
  # after
  #   :meck.unload(File)
  #   :meck.unload(System)
  #   :meck.unload(EEx)
  #   :meck.unload(FleetApi.Machine)
  # end   

  # test "get_journal - machineID and host success" do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :mkdir_p, fn path -> true end)
  #   :meck.expect(File, :write!, fn path, contents -> true end)
  #   :meck.expect(File, :rm_rf, fn path -> true end)
  #   :meck.expect(File, :exists?, fn path -> false end)
    
  #   :meck.new(System, [:unstick])
  #   :meck.expect(System, :cmd, fn cmd, opts, opts2 -> {"", 0} end)
  #   :meck.expect(System, :cwd!, fn -> "" end)

  #   :meck.new(EEx, [:unstick])
  #   :meck.expect(EEx, :eval_file, fn path, options -> "" end)
    
  #   machine_id = "#{UUID.uuid1()}"
  #   machine = Map.put(%{}, "id", machine_id)
  #   :meck.new(FleetApi.Machine, [:passthrough])
  #   :meck.expect(FleetApi.Machine, :list!, fn token -> [machine] end)

  #   unit = SystemdUnit.create!(Map.put(%{}, "machineID", machine_id))
  #   {result, stdout, stderr} = SystemdUnit.get_journal(unit)
  #   assert result == :ok
  #   assert stdout != nil
  #   assert stderr != nil
  # after
  #   :meck.unload(File)
  #   :meck.unload(System)
  #   :meck.unload(EEx)
  #   :meck.unload(FleetApi.Machine)
  # end  

  # test "get_journal - machineID and host failure" do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :mkdir_p, fn path -> true end)
  #   :meck.expect(File, :write!, fn path, contents -> true end)
  #   :meck.expect(File, :rm_rf, fn path -> true end)
  #   :meck.expect(File, :exists?, fn path -> false end)
    
  #   :meck.new(System, [:unstick])
  #   :meck.expect(System, :cmd, fn cmd, opts, opts2 -> {"", 128} end)
  #   :meck.expect(System, :cwd!, fn -> "" end)

  #   :meck.new(EEx, [:unstick])
  #   :meck.expect(EEx, :eval_file, fn path, options -> "" end)
    
  #   machine_id = "#{UUID.uuid1()}"
  #   machine = Map.put(%{}, "id", machine_id)
  #   :meck.new(FleetApi.Machine, [:passthrough])
  #   :meck.expect(FleetApi.Machine, :list!, fn token -> [machine] end)

  #   unit = SystemdUnit.create!(Map.put(%{}, "machineID", machine_id))
  #   {result, stdout, stderr} = SystemdUnit.get_journal(unit)
  #   assert result == :error
  #   assert stdout != nil
  #   assert stderr != nil
  # after
  #   :meck.unload(File)
  #   :meck.unload(System)
  #   :meck.unload(EEx)
  #   :meck.unload(FleetApi.Machine)
  # end
end