defmodule Plotto.DataTest do
  use ExUnit.Case, async: true

  alias Plotto.Data

  test "valid data list passes validation" do
    assert Data.validate([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]) == :ok
  end

  test "valid item may include an :attrs map" do
    assert Data.validate([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]) == :ok
  end

  test "rejects an empty list" do
    assert {:error, reason} = Data.validate([])
    assert reason =~ "empty"
  end

  test "rejects a non-list" do
    assert {:error, reason} = Data.validate(%{})
    assert reason =~ "list"
  end

  test "rejects an item missing :label" do
    assert {:error, _reason} = Data.validate([%{value: 10}])
  end

  test "rejects an item with a non-numeric :value" do
    assert {:error, _reason} = Data.validate([%{label: "Jan", value: "10"}])
  end

  test "rejects an item with a negative :value" do
    assert {:error, reason} = Data.validate([%{label: "Jan", value: -1}])
    assert reason =~ "negative"
  end
end
