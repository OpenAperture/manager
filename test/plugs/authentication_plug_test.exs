defmodule OpenAperture.Manager.Plugs.Authentication.Test do
  use ExUnit.Case, async: false
  use Plug.Test

  import OpenAperture.Manager.Plugs.Authentication
  import Ecto.Query

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.AuthSource
  alias OpenAperture.Manager.DB.Models.AuthSourceUserRelation
  alias OpenAperture.Manager.DB.Models.User

  setup do
    :meck.new(OpenAperture.Auth.Server)

    on_exit fn ->
      Repo.delete_all(AuthSourceUserRelation)
      Repo.delete_all(User)
      Repo.delete_all(AuthSource)
      :meck.unload
    end
  end

  test "fetch_access_token retrieves access token from auth header" do
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_req_header("authorization", "Bearer abcd1234")

    conn = fetch_access_token(conn, [])

    assert conn.private[:auth_access_token] == "abcd1234"
  end

  test "fetch_access_token retrieves access token from auth header even if header format is wrong" do
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_req_header("authorization", "Bearer access_token=abcd1234")

    conn = fetch_access_token(conn, [])

    assert conn.private[:auth_access_token] == "abcd1234"
  end

  test "fetch_access_token doesn't set private data if no auth header" do
    conn = Plug.Test.conn("GET", "/", nil)

    conn = fetch_access_token(conn, [])

    assert conn.private[:auth_access_token] == nil
  end

  test "fetch_access_token doesn't set private data if auth header doesn't contain an access token" do
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_req_header("authorization", "Bearer ")

    conn = fetch_access_token(conn, [])

    assert conn.private[:auth_access_token] == nil
  end

  test "fetch_access_token doesn't set private data if auth header is empty" do
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_req_header("authorization", "")

    conn = fetch_access_token(conn, [])

    assert conn.private[:auth_access_token] == nil
  end

  test "fetch_access_token doesn't set private data if auth header is only whitespace" do
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_req_header("authorization", "                      ")

    conn = fetch_access_token(conn, [])

    assert conn.private[:auth_access_token] == nil
  end

  test "authenticate user returns 401 if no access token is set" do
    conn = Plug.Test.conn("GET", "/", nil)

    conn = authenticate_user(conn, [])

    assert conn.status == 401
  end

  test "authenticate_user returns 401 is access token is invalid" do
    :meck.expect(OpenAperture.Auth.Server, :validate_token?, [{[:_, "access_token=abcd1234"], false}])
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_private(:auth_access_token, "abcd1234")

    conn = authenticate_user(conn, [])

    assert conn.status == 401
  end

  test "authenticate_user returns conn unchanged if access token is valid" do
    :meck.expect(OpenAperture.Auth.Server, :validate_token?, 2, true)
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_private(:auth_access_token, "abcd1234")

    conn2 = authenticate_user(conn, [])

    assert conn2 == conn
  end

  test "authenticate_user uses the specified token_info_url" do
    url = "http://test/token_info"
    # We'll get a `** (FunctionClauseError) no function clause matches` error
    # on this test if meck doesn't receive `url` as the first argument.
    :meck.expect(OpenAperture.Auth.Server, :validate_token?, [{[url, :_], true}])
    conn = Plug.Test.conn("GET", "/", nil)
           |> put_private(:auth_access_token, "abcd1234")

    conn2 = authenticate_user(conn, [token_info_url: url])

    assert conn2 == conn
    :meck.validate(OpenAperture.Auth.Server)
  end

  test "fetch_user adds the user record to the conn private data" do
    as = %AuthSource{
      token_info_url: "http://test/token",
      email_field_name: "user/email",
      first_name_field_name: "user/first_name",
      last_name_field_name: "user/last_name"}
    auth_source = Repo.insert(as)

    user = Repo.insert(%User{first_name: "test", last_name: "user", email: "test@test.com"})
    _relation = Repo.insert(%AuthSourceUserRelation{auth_source_id: auth_source.id, user_id: user.id})

    token_info = %{"user" => %{"first_name" => "test", "last_name" => "user", "email" => "test@test.com"}}

    :meck.expect(OpenAperture.Auth.Server, :token_info, 2, {:cached, token_info})

    conn = Plug.Test.conn("GET", "/", nil)
           |> put_private(:auth_access_token, "abcd1234")

    conn2 = fetch_user(conn, [token_info_url: auth_source.token_info_url])

    assert conn2 != conn

    assert conn2.private[:auth_user] == user
  end

  test "fetch_user adds the auth source and auth source-user relation if the auth source record doesn't exist" do
    token_info_url = "http://test.com/token"
    user = Repo.insert(%User{first_name: "test", last_name: "user", email: "test@test.com"})

    token_info = %{"resource_owner" => %{"email" => "test@test.com", "custom_attributes" => %{"first_name" => "test", "last_name" => "user"}}}

    :meck.expect(OpenAperture.Auth.Server, :token_info, 2, {:cached, token_info})

    conn = Plug.Test.conn("GET", "/", nil)
           |> put_private(:auth_access_token, "abcd1234")

    conn2 = fetch_user(conn, [token_info_url: token_info_url])

    assert conn2.private[:auth_user] == user

    query = where(AuthSource, [as], as.token_info_url == ^token_info_url)
    auth_source = Repo.one(query)
    assert auth_source != nil

    # Load the associated users to show the relation model has been created
    users = Repo.all(Ecto.Model.assoc(auth_source, :users))
    assert user in users
  end

  test "fetch_user adds the user record and relation if they don't already exist" do
    as = %AuthSource{
      token_info_url: "http://test/token",
      email_field_name: "user/email",
      first_name_field_name: "user/first_name",
      last_name_field_name: "user/last_name"}
    auth_source = Repo.insert(as)

    token_info = %{"user" => %{"first_name" => "test", "last_name" => "user", "email" => "test@test.com"}}

    :meck.expect(OpenAperture.Auth.Server, :token_info, 2, {:cached, token_info})

    conn = Plug.Test.conn("GET", "/", nil)
           |> put_private(:auth_access_token, "abcd1234")

    conn2 = fetch_user(conn, [token_info_url: auth_source.token_info_url])

    user = conn2.private[:auth_user]
    assert user != nil
    assert user.first_name == token_info["user"]["first_name"]
    assert user.last_name == token_info["user"]["last_name"]
    assert user.email == token_info["user"]["email"]

    # Load the associated users to show the relation model has been created
    users = Repo.all(Ecto.Model.assoc(auth_source, :users))
    assert user in users
  end

  test "fetch_user should work even with lots of simultaneous requests" do
    token_info_url = "http://test.com/token"
    token_info = %{"resource_owner" => %{"email" => "test@test.com", "custom_attributes" => %{"first_name" => "test", "last_name" => "user"}}}

    :meck.expect(OpenAperture.Auth.Server, :token_info, 2, {:cached, token_info})

    # Simulate a bunch of requests, all with the same access token
    tasks = Stream.repeatedly(fn ->
      Task.async(fn ->

        conn = Plug.Test.conn("GET", "/", nil)
               |> put_private(:auth_access_token, "abcd1234")

        conn2 = fetch_user(conn, [token_info_url: token_info_url])
        user = conn2.private[:auth_user]

        # Return the user record
        user
      end)
    end)

    result = tasks
             |> Enum.take(1000)
             |> Enum.map(&Task.await/1)
             |> Enum.all?(fn user ->
              user.first_name == "test"
              && user.last_name == "user"
              && user.email == "test@test.com"
             end)

    assert result == true
  end
end