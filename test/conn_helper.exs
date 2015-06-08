defmodule OpenAperture.Manager.Test.ConnHelper do
  defmacro __using__(_) do
    quote do
      import Phoenix.ConnTest

      def call(router, verb, path, params \\ nil, headers \\ []) do
        add_headers(Phoenix.ConnTest.conn(verb, path, params), headers)
        |> Plug.Conn.fetch_params
        |> Plug.Parsers.call(parsers: [Plug.Parsers.JSON],
                        pass: ["*/*"],
                        json_decoder: Poison)
        |> router.call(router.init([]))
      end

      def call_phoenix(router, verb, path, params \\ nil, headers \\ []) do
        conn = add_headers(Phoenix.ConnTest.conn(verb, path, params), headers)
        |> Plug.Conn.fetch_params
        |> Plug.Parsers.call(parsers: [Plug.Parsers.JSON],
                        pass: ["*/*"],
                        json_decoder: Poison)
        |> IO.inspect
        |> recycle
        |> Phoenix.ConnTest.dispatch(router, verb, path, params)
      end

      defp add_headers(connection, []) do
        connection
      end

      defp add_headers(connection, [header|remaining_headers]) do
        add_headers(Plug.Test.put_req_header(connection, "#{elem(header, 0)}", "#{elem(header, 1)}"), remaining_headers)
      end
    end
  end
end