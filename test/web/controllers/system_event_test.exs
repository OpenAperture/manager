defmodule OpenAperture.Manager.Controllers.SystemEventsTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Controllers.SystemEvents
  alias OpenAperture.Manager.DB.Models.SystemEvent

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn ->
      Repo.delete_all(SystemEvent)
      :meck.unload
    end    
    :ok
  end

  setup do
    Repo.delete_all(SystemEvent)
    :ok
  end

  @endpoint OpenAperture.Manager.Endpoint

  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end  

  # =====================
  # index tests

  test "all events in last 24 hours" do
    _event = Repo.insert!(%SystemEvent{type: "disk_space", inserted_at: from_erl(:calendar.universal_time)})

    conn = get conn(), "/system_events"
    assert conn.status == 200
    assert conn.resp_body != nil
    result = Poison.decode!(conn.resp_body)
    assert result != nil
    assert length(result) == 1
  end

  # =====================
  # create tests

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert!, fn _ -> raise "bad news bears" end)

    conn = post conn(), "/system_events", %{"type" => "disk_space"}
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - success" do
    conn = post conn(), "/system_events", %{"type" => "disk_space"}
    assert conn.status == 201
    location_header = Enum.reduce conn.resp_headers, nil, fn ({key, value}, location_header) ->
      if key == "location" do
        value
      else
        location_header
      end
    end
    assert location_header != nil
    assert String.contains?(location_header, "/system_events")
  end  
end