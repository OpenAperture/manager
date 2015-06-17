defmodule OpenAperture.Manager.Plugs.Authentication.Test do
  use ExUnit.Case, async: false
  use Plug.Test

  import OpenAperture.Manager.Plugs.Authentication

  setup do
    :meck.new(OpenAperture.Auth.Server)

    on_exit fn ->
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
end