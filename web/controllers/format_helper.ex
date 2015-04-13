defmodule OpenAperture.Manager.Controllers.FormatHelper do
  @moduledoc """
  This module provides helper functions that are used by controllers to
  format incoming and outgoing data.
  """

  @doc """
  to_sendable prepares a struct or map for transmission by converting structs
  to plain old maps (if a struct is passed in), and stripping out any fields
  in the allowed_fields list. If allowed_fields is empty, then all fields are
  sent.
  """
  @spec to_sendable(Map.t, List.t) :: Map.t
  def to_sendable(item, allowed_fields \\ [])

  def to_sendable(item, []) do
    to_sendable(item, Map.keys(item))
  end

  def to_sendable(%{__struct__: _} = struct, allowed_fields) do
    struct
    |> Map.from_struct
    |> to_sendable(allowed_fields)
  end

  def to_sendable(item, allowed_fields) do
    item
    |> Map.take(allowed_fields)
  end

  @doc """
  keywords_to_map converts a keyword list to a map, which is more easily
  transmitted as a JSON object. If a key is repeated in the keyword list, then
  the value in the map is represented as a list.
  Ex:
  [a: "First value", b: "Second value", c: "Third value"] becomes
  %{a: ["First value", "Third value"], b: "Second value"}
  """
  @spec keywords_to_map(Keyword) :: Map
  def keywords_to_map(kw) do
    kw
    |> Enum.reduce(
      %{},
      fn {key, value}, acc ->
        current = acc[key]
        case current do
          nil -> Map.put(acc, key, value)
          [single] -> Map.put(acc, key, [single, value])
          [_ | _] -> Map.put(acc, key, current ++ [value])
          _ -> Map.put(acc, key, [current, value])
        end
      end)
  end
end