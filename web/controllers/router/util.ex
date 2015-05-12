defmodule OpenAperture.Manager.Controllers.Router.Util do
  @doc """
  Parses a string of the form hostname:port into its separate hostname
  and port components. Supports URL-encoded colons.

  ## Example

      iex> OpenAperture.Manager.Controllers.Router.Util.parse_hostspec("test:80")
      {:ok, "test", 80}

      iex> OpenAperture.Manager.Controllers.Router.Util.parse_hostspec("test%3A80")
      {:ok, "test", 80}

      iex> OpenAperture.Manager.Controllers.Router.Util.parse_hostspec("test%3a80")
      {:ok, "test", 80}
  """
  @spec parse_hostspec(String.t) :: {:ok, String.t, integer} | :error
  def parse_hostspec(authority) do
    colon_regex = ~r/(?<hostname>.*):(?<port>\d+)$/
    urlencoded_regex = ~r/(?<hostname>.*)%3[aA](?<port>\d+)$/

    cond do
      Regex.match?(colon_regex, authority) ->
        captures = Regex.named_captures(colon_regex, authority)
        {:ok, captures["hostname"], String.to_integer(captures["port"])}

      Regex.match?(urlencoded_regex, authority) ->
        captures = Regex.named_captures(urlencoded_regex, authority)
        {:ok, captures["hostname"], String.to_integer(captures["port"])}

      true -> :error
    end
  end
end