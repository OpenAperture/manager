defmodule OpenAperture.Manager.Controllers.UsersTest do
  use ExUnit.Case, [async: false]
  use Phoenix.ConnTest

  alias OpenAperture.Manager
  alias Manager.DB.Models.User
  alias Manager.Repo
  alias Manager.Plugs.Authentication

  @endpoint OpenAperture.Manager.Endpoint
  @params %{first_name: "John", last_name: "Doe", email: "jdoe@mail.com"}

  setup_all do
    user = User.new(@params) |> Repo.insert

    :meck.new(Authentication, [:passthrough])
    :meck.expect(Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn ->
      :meck.unload
      Repo.delete_all(User)
    end

    {:ok, %{user: user}}
  end

  test "index action", %{user: user} do
    conn = get(conn, "/users")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) > 0

    user_entry = Enum.fetch!(body, 0)
    assert user_entry["id"]         == user.id
    assert user_entry["first_name"] == user.first_name
    assert user_entry["last_name"]  == user.last_name
    assert user_entry["email"]      == user.email
  end

  test "show action - found", %{user: user} do
    conn = get(conn, "/users/#{user.id}")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert body["id"] == user.id
  end

  test "show action - not found" do
    assert get(conn, "users/0").status == 404
  end

  test "create action - success" do
    params =
      %{id: 2, first_name: "Josh", last_name: "Done", email: "jdone@mail.com"}

    conn = post(conn, "users", params)
    assert conn.status == 201
  end

  test "create action - bad request on invalid values" do
    conn = post(conn, "users", %{})
    assert conn.status    == 400
    assert conn.resp_body =~ ~r/first_name/
    assert conn.resp_body =~ ~r/last_name/
    assert conn.resp_body =~ ~r/email/
  end

  test "update action - success" do
    user   = User.new(%{@params | email: "up@mail.com"}) |> Repo.insert
    update = %{first_name: "Johanna", last_name: "Dawn", email: "jdawn@mail.com"}
    conn   = put(conn, "users/#{user.id}", update)

    assert conn.status == 204
  end

  test "update action - not found" do
    assert put(conn, "users/0").status == 404
  end

  test "update action - fails on invalid values", %{user: user} do
    conn = put(conn, "users/#{user.id}", %{email: "test"})
    assert conn.status    == 400
    assert conn.resp_body =~ ~r/email/
  end

  test "delete action - success" do
    user = User.new(%{@params | email: "del@mail.com"}) |> Repo.insert
    conn = delete(conn, "users/#{user.id}")
    assert conn.status == 204
  end

  test "delete action - not found" do
    assert delete(conn, "users/0").status == 404
  end
end
