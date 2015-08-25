require Logger

defmodule OpenAperture.Manager.Controllers.FormatHelper do
  use Timex

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
  @spec to_sendable(Map.t, List.t, List.t) :: Map.t
  def to_sendable(item, allowed_fields \\ [], encrypted_fields \\ [])

  @doc """
  to_sendable prepares a List of structs or maps for transmission by converting structs
  to plain old maps (if a struct is passed in), and stripping out any fields
  in the allowed_fields list. If allowed_fields is empty, then all fields are
  sent.
  """
  def to_sendable(item, allowed_fields, encrypted_fields) when is_list(item), do: to_sendable_list([], item, allowed_fields, encrypted_fields)
  def to_sendable(item, [], encrypted_fields), do: to_sendable(item, Map.keys(item), encrypted_fields)

  def to_sendable(%{__struct__: _} = struct, allowed_fields, encrypted_fields) do
    struct
    |> Map.from_struct
    |> to_sendable(allowed_fields, encrypted_fields)
  end

  def to_sendable(item, allowed_fields, encrypted_fields) do
    item
    |> Map.take(allowed_fields)
    |> to_string_timestamps
    |> unencrypt_fields(encrypted_fields)
  end

  @spec unencrypt_fields(map, list) :: map
  def unencrypt_fields(item, []), do: item
  def unencrypt_fields(item, [key | tail]), do: unencrypt_field(item, key, item[key]) |> unencrypt_fields(tail)

  @spec unencrypt_field(map, String.t, String.t) :: map
  def unencrypt_field(item, _, nil), do: item
  def unencrypt_field(item, key, val), do: Map.put(item, key, decrypt_value(val))

  @spec encrypt_value(String.t()) :: String.t()
  def encrypt_value(value) do
    try do
      keyfile =  Application.get_env(:openaperture_messaging, :public_key)
      if File.exists?(keyfile) do
        public_key = RSA.decode_key(File.read!(keyfile))
        cyphertext = value |> RSA.encrypt {:public, public_key}
        "#{:base64.encode_to_string(cyphertext)}"
      else
        raise "Error retrieving public key:  File #{keyfile} does not exist!"
      end
    rescue
      e ->
        raise "Error retrieving public key:  #{inspect e}"
    end
  end

  @spec decrypt_value(String.t()) :: String.t()
  def decrypt_value(encrypted_value) do
    try do
      keyfile =  Application.get_env(:openaperture_messaging, :private_key)
      if File.exists?(keyfile) do     
        private_key = RSA.decode_key(File.read!(keyfile))
        cyphertext = :base64.decode(encrypted_value)
        "#{RSA.decrypt cyphertext, {:private, private_key}}"
      else
       raise "Error retrieving private key:  File #{keyfile} does not exist!"
      end
    rescue
      e ->
        raise "Error retrieving private key:  #{inspect e}"
    end   
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

  defp to_sendable_list(sendable_items, [], _, _encrypted_fields), do: sendable_items
  
  defp to_sendable_list(sendable_items, [item|remaining_items], allowed_fields, encrypted_fields) do
    to_sendable_list(sendable_items ++ [to_sendable(item, allowed_fields, encrypted_fields)], remaining_items, allowed_fields, encrypted_fields)
  end

  @doc """
  Method to convert the :inserted_at and :updated_at entries into RFC 1123-compliant Strings
  """
  @spec to_string_timestamps(Map.t) :: Map.t
  def to_string_timestamps(item)  when is_list(item), do: to_string_timestamps_list([], item)

  @doc """
  Method to convert the :inserted_at and :updated_at entries into RFC 1123-compliant Strings
  """
  def to_string_timestamps(item) do
    if item[:inserted_at] != nil do
      {:ok, erl_date} = Ecto.DateTime.dump(item[:inserted_at])
      date = Date.from(erl_date, :utc)
      item = Map.put(item, :inserted_at, DateFormat.format!(date, "{RFC1123}"))
    end

    if item[:updated_at] != nil do
      {:ok, erl_date} = Ecto.DateTime.dump(item[:updated_at])
      date = Date.from(erl_date, :utc)
      item = Map.put(item, :updated_at, DateFormat.format!(date, "{RFC1123}"))
      
    end

    item
  end

  defp to_string_timestamps_list(updated_items, []), do: updated_items
  
  defp to_string_timestamps_list(updated_items, [item|remaining_items]) do
    to_string_timestamps_list(updated_items ++ [to_string_timestamps(item)], remaining_items)
  end  
end