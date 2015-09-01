defmodule OpenAperture.Manager.BuildLogMonitorTest do
  use ExUnit.Case

  alias OpenAperture.Manager.Messaging.ManagerQueue
  alias OpenAperture.Manager.BuildLogMonitor

  setup do
    :ok
  after
    :meck.unload
  end

  test "init" do
    call_count_pid = SimpleAgent.start! 0
    :meck.new(ManagerQueue, [:passthrough])
    :meck.expect(ManagerQueue, :build_and_subscribe, fn queue_name, _fun ->
                        assert queue_name == "build_logs"
                        SimpleAgent.increment! call_count_pid
                      end)
    assert BuildLogMonitor.init(:ok) == {:ok, nil}
    assert SimpleAgent.get!(call_count_pid) == 1
  end
end