defmodule Plotto.DataTest do
  use ExUnit.Case, async: true

  alias Plotto.Data

  test "a valid single-series list passes validation" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]
    assert Data.validate(data) == :ok
  end

  test "a valid multi-series list with matching labels and names passes validation" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    assert Data.validate(data) == :ok
  end

  test "a single series may have a nil :name" do
    data = [%{name: nil, data: [%{label: "Jan", value: 10}]}]
    assert Data.validate(data) == :ok
  end

  test "a valid item may include an :attrs map" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}]
    assert Data.validate(data) == :ok
  end

  test "rejects an empty list" do
    assert {:error, reason} = Data.validate([])
    assert reason =~ "empty"
  end

  test "rejects a non-list" do
    assert {:error, reason} = Data.validate(%{})
    assert reason =~ "list"
  end

  test "rejects a series missing :name or :data" do
    assert {:error, reason} = Data.validate([%{data: [%{label: "Jan", value: 10}]}])
    assert reason =~ "invalid series"
  end

  test "rejects a non-map series element" do
    assert {:error, reason} = Data.validate([1, 2])
    assert reason =~ "invalid series"
  end

  test "rejects a series with an empty :data list" do
    assert {:error, reason} = Data.validate([%{name: "Sales", data: []}])
    assert reason =~ "must not be empty"
  end

  test "rejects an item missing :label" do
    data = [%{name: "Sales", data: [%{value: 10}]}]
    assert {:error, _reason} = Data.validate(data)
  end

  test "rejects an item with a non-numeric :value" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: "10"}]}]
    assert {:error, _reason} = Data.validate(data)
  end

  test "rejects an item with a negative :value" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: -1}]}]
    assert {:error, reason} = Data.validate(data)
    assert reason =~ "negative"
  end

  test "rejects mismatched labels across series" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Mar", value: 8}]}
    ]

    assert {:error, reason} = Data.validate(data)
    assert reason =~ "labels must match"
  end

  test "rejects mismatched label counts across series" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    assert {:error, reason} = Data.validate(data)
    assert reason =~ "labels must match"
  end

  test "rejects a nil :name when there are 2+ series" do
    data = [
      %{name: nil, data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    assert {:error, reason} = Data.validate(data)
    assert reason =~ "name is required"
  end
end
