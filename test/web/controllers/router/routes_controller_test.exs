defmodule OpenAperture.Manager.Controllers.Router.RoutesController.Test do
  use ExUnit.Case, async: false
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.DB.Models.Router.Authority
  alias OpenAperture.Manager.DB.Models.Router.DeletedAuthority
  alias OpenAperture.Manager.DB.Models.Router.Route
  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Router

  setup do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    # Make the entries old
    datetime = Ecto.DateTime.from_date_and_time(
      %Ecto.Date{year: 2014, month: 1, day: 1},
      %Ecto.Time{hour: 1, min: 1, sec: 1})

    a1 = Repo.insert(%Authority{hostname: "test", port: 80, inserted_at: datetime, updated_at: datetime})
    a2 = Repo.insert(%Authority{hostname: "test2", port: 80, inserted_at: datetime, updated_at: datetime})

    Repo.insert(%Route{authority_id: a1.id, hostname: "east.test", port: 80, inserted_at: datetime, updated_at: datetime})
    Repo.insert(%Route{authority_id: a1.id, hostname: "west.test", port: 80, inserted_at: datetime, updated_at: datetime})
    Repo.insert(%Route{authority_id: a1.id, hostname: "test.test", port: 80, inserted_at: datetime, updated_at: datetime})
    Repo.insert(%Route{authority_id: a1.id, hostname: "staging.test", port: 80, inserted_at: datetime, updated_at: datetime})

    Repo.insert(%Route{authority_id: a2.id, hostname: "main.test2", port: 80, inserted_at: datetime, updated_at: datetime})

    Repo.insert(%DeletedAuthority{hostname: "test.host", port: 1, inserted_at: datetime, updated_at: datetime})
    Repo.insert(%DeletedAuthority{hostname: "test.host", port: 2, inserted_at: datetime, updated_at: datetime})
    Repo.insert(%DeletedAuthority{hostname: "test.host", port: 3, inserted_at: datetime, updated_at: datetime})
    Repo.insert(%DeletedAuthority{hostname: "test.host", port: 3, inserted_at: datetime, updated_at: datetime})

    on_exit fn ->
      Repo.delete_all(Route)
      Repo.delete_all(DeletedAuthority)
      Repo.delete_all(Authority)

      try do
        :meck.unload(OpenAperture.Manager.Plugs.Authentication)
      rescue _ -> IO.puts "" end
    end

    {:ok, a1: a1, a2: a2}
  end

  test "GET /router/routes" do
    path = routes_path(Endpoint, :index)
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    assert Map.has_key?(body, "test:80")
    assert Map.has_key?(body, "test2:80")
    assert Map.has_key?(body, "timestamp")

    assert length(body["test:80"]) == 4
    assert length(body["test2:80"]) == 1
  end

  test "retrieve only updated routes -- no updates" do
    path = routes_path(Endpoint, :index)
    conn = call(Router, :get, path)
    
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    timestamp = body["timestamp"]

    # Wait a second...
    :timer.sleep(1000)
    path = routes_path(Endpoint, :index, updated_since: timestamp)
    conn = call(Router, :get, path)
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(Map.keys(body)) == 1
    assert Map.has_key?(body, "timestamp")

    assert body["timestamp"] > timestamp
  end

  test "retrieve updated routes -- with updates" do
    now = :os.timestamp
    {date, {hour, min, sec}} = :calendar.now_to_universal_time(now)
    {:ok, create_datetime} = Ecto.DateTime.load({date, {hour, min, sec, 0}})

    new_authority = Repo.insert(%Authority{hostname: "NewAuthority", port: 1, inserted_at: create_datetime, updated_at: create_datetime})
    Repo.insert(%Route{authority_id: new_authority.id, hostname: "NewRoute", port: 1, inserted_at: create_datetime, updated_at: create_datetime})

    {megas, secs, _} = now
    timestamp = megas * 1_000_000 + secs

    path = routes_path(Endpoint, :index)
    conn = call(Router, :get, path, updated_since: timestamp)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(Map.keys(body)) == 2
    assert Map.has_key?(body, "#{new_authority.hostname}:#{new_authority.port}")
  end

  test "retrieve all deleted routes" do
    path = routes_path(Endpoint, :index_deleted)
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 3
    assert "test.host:1" in body
    assert "test.host:2" in body
    assert "test.host:3" in body
  end

  test "retrieve only newly-deleted routes -- none" do
    path = routes_path(Endpoint, :index)
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    timestamp = body["timestamp"]
    # Wait a second...
    :timer.sleep(1000)
    path = routes_path(Endpoint, :index_deleted, updated_since: timestamp)
    conn = call(Router, :get, path)
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "retrieve newly-deleted routes" do
    path = routes_path(Endpoint, :index)
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    timestamp = body["timestamp"]

    deleted_authority = Repo.insert(%DeletedAuthority{hostname: "test", port: 9})

    path = routes_path(Endpoint, :index_deleted, updated_since: timestamp)
    conn = call(Router, :get, path)
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    assert length(body) == 1
    first = List.first(body)
    assert first == "#{deleted_authority.hostname}:#{deleted_authority.port}"
  end
end