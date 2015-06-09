defmodule OpenAperture.Manager.Plugs.Params.Test do
  use ExUnit.Case
  use Plug.Test

  import OpenAperture.Manager.Plugs.Params

  test "parse_as_integer returns 404 if the param isn't parseable" do
    conn = Plug.Test.conn("GET", "/", %{"id" => "not an integer!"})

    conn = parse_as_integer(conn, "id")

    assert conn.status == 404
  end

  test "parse_as_integer returns the int provided if param was already an integer" do
    conn = Plug.Test.conn("GET", "/", %{"id" => 1337})

    conn = parse_as_integer(conn, "id")

    assert conn.params["id"] == 1337
  end

  test "parse_as_integer returns a parsed int if params was a valid integer string" do
    conn = Plug.Test.conn("GET", "/", %{"id" => "1337"})

    conn = parse_as_integer(conn, "id")

    assert conn.params["id"] == 1337
  end

  test "parse_as_integer returns the custom error status code if the param isn't parseable" do
    conn = Plug.Test.conn("GET", "/", %{"some_param" => "not an integer!"})

    conn = parse_as_integer(conn, {"some_param", 400})

    assert conn.status == 400
  end

  test "parse_as_integer returns the conn if the specified param isn't present" do
    conn = Plug.Test.conn("GET", "/", %{})

    conn2 = parse_as_integer(conn, "port")

    assert conn2 == conn
  end

  test "validate_param sets the status and halts if validation fails" do
    conn = Plug.Test.conn("GET", "/", %{"name" => 1234})

    conn = validate_param(conn, {"name", &Kernel.is_binary/1})

    assert conn.status == 400
  end

  test "validate_param sets the custom status and halts if validation fails" do
    conn = Plug.Test.conn("GET", "/", %{"port" => "not an integer"})

    conn = validate_param(conn, {"port", &Kernel.is_integer/1, 404})

    assert conn.status == 404
  end

  test "validate_param doesn't modify the conn if the param validates" do
    conn = Plug.Test.conn("GET", "/", %{"port" => 1234})

    conn2 = validate_param(conn, {"port", &Kernel.is_integer/1})

    assert conn2 == conn
  end

  test "validate_param doesn't modify the conn if the param to validate isn't present" do
    conn = Plug.Test.conn("GET", "/", %{})

    conn2 = validate_param(conn, {"port", &Kernel.is_integer/1})

    assert conn2 == conn
  end
end