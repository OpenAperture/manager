defmodule ProjectOmeletteManager.Test.ConnHelper do
  defmacro __using__(_) do
    quote do
      import Plug.Test

      def call(router, verb, path, params \\ nil, headers \\ []) do
        conn(verb, path, params, headers)
        |> Plug.Conn.fetch_params
        |> Plug.Parsers.call(parsers: [Plug.Parsers.JSON],
                        pass: ["*/*"],
                        json_decoder: Poison)
        |> router.call(router.init([]))
      end
    end
  end
end