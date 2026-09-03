defmodule Plotto.LineDataTest do
  use ExUnit.Case, async: true

  alias Plotto.LineData

  test "a valid single-series list passes validation" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]
    assert LineData.validate(data) == :ok
  end

  test "a valid multi-series list passes validation even with different labels" do
    data = [
      %{name: "Series 1", data: [%{label: "1", value: 10}, %{label: "2", value: 25}]},
      %{
        name: "Series 2",
        data: [%{label: "1", value: 5}, %{label: "2", value: 8}, %{label: "3", value: 12}]
      }
    ]

    assert LineData.validate(data) == :ok
  end

  test "a flat list of items passes validation and normalizes to single series" do
    flat = [%{label: "Jan", value: 10}, %{label: "Feb", value: 20}]
    assert LineData.validate(flat) == :ok
    assert LineData.normalize(flat) == [%{name: nil, data: flat}]
  end

  test "a single series may have a nil :name" do
    data = [%{name: nil, data: [%{label: "Jan", value: 10}]}]
    assert LineData.validate(data) == :ok
    assert LineData.normalize(data) == data
  end

  test "rejects an empty list" do
    assert {:error, reason} = LineData.validate([])
    assert reason =~ "empty"
  end

  test "rejects a non-list" do
    assert {:error, reason} = LineData.validate(%{})
    assert reason =~ "list"
  end

  test "rejects a series missing :data" do
    assert {:error, reason} = LineData.validate([%{name: "Sales"}])
    assert reason =~ "invalid series"
  end

  test "rejects a series with an empty :data list" do
    assert {:error, reason} = LineData.validate([%{name: "Sales", data: []}])
    assert reason =~ "must not be empty"
  end

  test "rejects a nil :name when there are 2+ series" do
    data = [
      %{name: nil, data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    assert {:error, reason} = LineData.validate(data)
    assert reason =~ "name is required"
  end

  test "rejects an item with a non-numeric :value" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: "10"}]}]
    assert {:error, _reason} = LineData.validate(data)
  end
end
