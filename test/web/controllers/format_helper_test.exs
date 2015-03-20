defmodule ProjectOmeletteManager.Controllers.FormatHelper.Test do
  use ExUnit.Case

  import ProjectOmeletteManager.Controllers.FormatHelper

  defmodule Controllers.FormatHelper.Test.TestStruct do
    defstruct name: "test struct", rank: 17, color: :blue, spin: :up
  end

  alias Controllers.FormatHelper.Test.TestStruct

  test "to_sendable, no allowed_fields specified should return all fields" do
    teststruct = %TestStruct{}

    result = to_sendable(teststruct)

    # Get all of TestStruct's keys (except for :__struct__, of course)
    struct_keys = Map.keys(teststruct) |> Enum.filter(fn key -> key != :__struct__ end)

    assert Enum.into(Map.keys(result), HashSet.new) == Enum.into(struct_keys, HashSet.new)
    assert result[:name] == "test struct"
    assert result[:rank] == 17
    assert result[:color] == :blue
    assert result[:spin] == :up
  end

  test "to_sendable with specified fields should return just those fields" do
    teststruct = %TestStruct{}

    fields = [:name, :color]

    result = to_sendable(teststruct, fields)

    assert Enum.into(Map.keys(result), HashSet.new) == Enum.into(fields, HashSet.new)
    assert result[:name] == "test struct"
    assert result[:color] == :blue
  end

  test "to_sendable with a single specified field should return the single field" do
    teststruct = %TestStruct{}

    fields = [:spin]

    result = to_sendable(teststruct, fields)

    assert Enum.into(Map.keys(result), HashSet.new) == Enum.into(fields, HashSet.new)
    assert result[:spin] == :up
  end

  test "keywords_to_map - single keyword" do
    kw = [a: "a value"]
    assert keywords_to_map(kw) == %{a: "a value"}
  end

  test "keywords_to_map - multiple keywords" do
    kw = [a: "a value", b: "b value"]
    assert keywords_to_map(kw) == %{a: "a value", b: "b value"}
  end

  test "keywords_to_map - single keyword, multiple values" do
    kw = [a: "a value", a: "a value 2", a: "a value 3"]
    assert keywords_to_map(kw) == %{a: ["a value", "a value 2", "a value 3"]}
  end

  test "keywords_to_map - multiple keywords, multiple values" do
    kw = [a: "a value", b: "b value", b: "b value 2", a: "a value 2"]
    assert keywords_to_map(kw) == %{a: ["a value", "a value 2"], b: ["b value", "b value 2"]}
  end
end
