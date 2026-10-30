defmodule Plotto.GaugeDataTest do
  use ExUnit.Case, async: true

  alias Plotto.GaugeData

  test "validates a single number" do
    assert GaugeData.validate(75) == :ok
    assert GaugeData.validate(0) == :ok
    assert GaugeData.validate(-12.5) == :ok
  end

  test "validates a single gauge item map" do
    assert GaugeData.validate(%{value: 75}) == :ok
    assert GaugeData.validate(%{label: "CPU", value: 75}) == :ok
    assert GaugeData.validate(%{name: "CPU", value: 75, color: "#2ECC71"}) == :ok

    assert GaugeData.validate(%{
             label: "CPU",
             value: 75,
             attrs: %{"phx-click" => "select"}
           }) == :ok
  end

  test "validates a non-empty list of gauge items" do
    assert GaugeData.validate([%{label: "CPU", value: 75}, %{label: "RAM", value: 60}]) == :ok
    assert GaugeData.validate([75, 60]) == :ok
  end

  test "rejects an empty list or invalid data" do
    assert {:error, reason} = GaugeData.validate([])
    assert reason =~ "empty"

    assert {:error, _} = GaugeData.validate("invalid")
    assert {:error, _} = GaugeData.validate(%{label: "CPU"})
    assert {:error, _} = GaugeData.validate(%{value: "75"})
    assert {:error, _} = GaugeData.validate(%{value: 75, label: 123})
    assert {:error, _} = GaugeData.validate(%{value: 75, color: 123})
    assert {:error, _} = GaugeData.validate(%{value: 75, attrs: "invalid"})
    assert {:error, _} = GaugeData.validate([%{value: 75}, :invalid])
  end

  describe "normalize/1" do
    test "normalizes a number into a single-element list" do
      assert GaugeData.normalize(75) == [%{label: nil, value: 75}]
    end

    test "normalizes a single map into a single-element list" do
      assert GaugeData.normalize(%{name: "CPU", value: 75, color: "#FF0000"}) == [
               %{label: "CPU", value: 75, color: "#FF0000"}
             ]
    end

    test "normalizes a list of items" do
      assert GaugeData.normalize([%{label: "CPU", value: 75}, 40]) == [
               %{label: "CPU", value: 75},
               %{label: nil, value: 40}
             ]
    end
  end
end
