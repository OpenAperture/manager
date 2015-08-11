defmodule OpenAperture.Manager.Controllers.SystemEventsTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Controllers.SystemEvents
  alias OpenAperture.Manager.DB.Models.SystemEvent
  alias OpenAperture.Manager.DB.Models.User

  alias OpenAperture.Manager.Notifications.Publisher

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    :meck.new(Publisher, [:passthrough])
    on_exit fn ->
      Repo.delete_all(SystemEvent)
      Repo.delete_all(User)
      :meck.unload
    end    
    :ok
  end

  setup do
    Repo.delete_all(SystemEvent)
    Repo.delete_all(User)
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

  test "index - assigned event", context do
    user = Repo.insert!(%User{first_name: "test", last_name: "user", email: "test@test.com"})
    event = Repo.insert!(%SystemEvent{type: "disk_space", inserted_at: from_erl(:calendar.universal_time), assignee_id: user.id})
    event2 = Repo.insert!(%SystemEvent{type: "disk_space", inserted_at: from_erl(:calendar.universal_time)})

    conn = get conn(), "/system_events?assignee_id=#{user.id}"
    assert conn.status == 200

    returned_events = Poison.decode!(conn.resp_body)
    assert returned_events != nil
    assert length(returned_events) == 1
  end    

  test "index - assigned events", context do
    user1 = Repo.insert!(%User{first_name: "test", last_name: "user", email: "test@test.com"})
    user2 = Repo.insert!(%User{first_name: "test2", last_name: "user2", email: "test2@test.com"})

    event1_to_user1 = Repo.insert!(%SystemEvent{
      type: "disk_space", 
      assignee_id: user1.id,
      assigned_by_id: user1.id,
      inserted_at: from_erl(:calendar.universal_time)}
      )

    event2_to_user1 = Repo.insert!(%SystemEvent{
      type: "disk_space", 
      assignee_id: user1.id,
      assigned_by_id: user1.id,
      inserted_at: from_erl(:calendar.universal_time)}
      )

    event3_to_user2 = Repo.insert!(%SystemEvent{
      type: "disk_space", 
      assignee_id: user2.id,
      assigned_by_id: user1.id,
      inserted_at: from_erl(:calendar.universal_time)}
      )

    conn = get conn(), "/system_events?assignee_id=#{user1.id}"
    assert conn.status == 200

    returned_events = Poison.decode!(conn.resp_body)
    assert returned_events != nil
    assert length(returned_events) == 2
    result = Enum.reduce returned_events, true, fn (returned_event, result) ->
      cond do
        !result -> result
        returned_event["assignee_id"] != user1.id -> false
        true -> true 
      end
    end
    assert result

    conn = get conn(), "/system_events?assignee_id=#{user2.id}"
    assert conn.status == 200

    returned_events = Poison.decode!(conn.resp_body)
    assert returned_events != nil
    assert length(returned_events) == 1
    result = Enum.reduce returned_events, true, fn (returned_event, result) ->
      cond do
        !result -> result
        returned_event["assignee_id"] != user2.id -> false
        true -> true 
      end
    end
    assert result
  end 
  # =====================
  # create tests

  test "create - internal server error" do
    :meck.new(Repo, [:passthrough])
    :meck.expect(Repo, :all, fn _ -> [] end)
    :meck.expect(Repo, :insert!, fn _ -> raise "bad news bears" end)

    conn = post conn(), "/system_events", %{"type" => "disk_space", "severity" => "error"}
    assert conn.status == 500
  after
    :meck.unload(Repo)
  end

  test "create - missing type" do
    conn = post conn(), "/system_events", %{}
    assert conn.status == 400
  end  

  test "create - missing severity" do
    conn = post conn(), "/system_events", %{"severity" => "error"}
    assert conn.status == 400
  end  

  test "create - success" do
    conn = post conn(), "/system_events", %{"type" => "disk_space", "severity" => "error"}
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

  test "create - success wit duplicate" do
    data = %{
        "test" => "#{UUID.uuid1()}"
      }
    event = Repo.insert!(%SystemEvent{
      type: "disk_space", 
      data: Poison.encode!(data),
      inserted_at: from_erl(:calendar.universal_time)})

    conn = post conn(), "/system_events", %{"type" => "disk_space", "severity" => "error", "data" => data}
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

  test "create - conflict" do
    data = %{
        "test" => "#{UUID.uuid1()}"
      }
    event = Repo.insert!(%SystemEvent{
      type: "disk_space", 
      data: Poison.encode!(data),
      inserted_at: from_erl(:calendar.universal_time)})
    
    conn = post conn(), "/system_events", %{"type" => "disk_space", "severity" => "error", "data" => data, "unique" => true}
    assert conn.status == 409
  end

  # ==================================
  # show tests

  test "show - invalid event" do
    conn = get conn(), "/system_events/1234567890"
    assert conn.status == 404
  end

  test "show - valid event", context do
    event = Repo.insert!(%SystemEvent{type: "disk_space", inserted_at: from_erl(:calendar.universal_time)})

    conn = get conn(), "/system_events/#{event.id}"
    assert conn.status == 200

    returned_event = Poison.decode!(conn.resp_body)
    assert returned_event != nil
  end    

  # =====================
  # assign tests

  test "assign - invalid event" do
    conn = post conn(), "/system_events/1234567890/assign", %{}
    assert conn.status == 404
  end

  test "assign - no assignee" do
    event = Repo.insert!(%SystemEvent{type: "disk_space", severity: "error", inserted_at: from_erl(:calendar.universal_time)})

    user = Repo.insert!(%User{first_name: "test", last_name: "user", email: "test@test.com"})

    conn = 
      conn()
      |> put_private(:auth_user, user)
      |> post "/system_events/#{event.id}/assign", %{}
    assert conn.status == 400
  end   

  test "assign - success" do
    :meck.expect(Publisher, :email_notification, fn _,_,_ -> :ok end)

    event = Repo.insert!(%SystemEvent{type: "disk_space", severity: "error", inserted_at: from_erl(:calendar.universal_time)})
    user = Repo.insert!(%User{first_name: "test", last_name: "user", email: "test@test.com"})

    conn = 
      conn()
      |> put_private(:auth_user, user)
      |> post "/system_events/#{event.id}/assign", %{assignee_id: user.id}

    assert conn.status == 204
  end    

  # =====================
  # dismiss tests

  test "dismiss - invalid event" do
    conn = post conn(), "/system_events/1234567890/dismiss", %{}
    assert conn.status == 404
  end

  test "dismiss - no dismissed_by" do
    event = Repo.insert!(%SystemEvent{type: "disk_space", severity: "error", inserted_at: from_erl(:calendar.universal_time)})

    user = Repo.insert!(%User{first_name: "test", last_name: "user", email: "test@test.com"})

    conn = 
      conn()
      |> put_private(:auth_user, user)
      |> post "/system_events/#{event.id}/dismiss", %{}
    assert conn.status == 204
  end   

  test "dismiss - success" do
    :meck.expect(Publisher, :email_notification, fn _,_,_ -> :ok end)
    
    event = Repo.insert!(%SystemEvent{type: "disk_space", severity: "error", inserted_at: from_erl(:calendar.universal_time)})
    user = Repo.insert!(%User{first_name: "test", last_name: "user", email: "test@test.com"})

    conn = 
      conn()
      |> put_private(:auth_user, user)
      |> post "/system_events/#{event.id}/dismiss", %{dismissed_by_id: user.id}

    assert conn.status == 204
  end
end