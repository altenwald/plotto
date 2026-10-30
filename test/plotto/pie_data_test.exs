defmodule Plotto.PieDataTest do
  use ExUnit.Case, async: true

  alias Plotto.PieData

  test "validates a flat list of slice maps" do
    assert PieData.validate([
             %{label: "Desktop", value: 65},
             %{label: "Mobile", value: 30},
             %{label: "Tablet", value: 5}
           ]) == :ok

    assert PieData.validate([
             %{name: "Desktop", value: 65, color: "#4E79A7", attrs: %{"phx-click" => "select"}},
             %{name: "Mobile", value: 0}
           ]) == :ok
  end

  test "validates a multi-series list of slice maps" do
    assert PieData.validate([
             %{
               name: "2025",
               data: [%{label: "Desktop", value: 60}, %{label: "Mobile", value: 40}]
             },
             %{
               name: "2026",
               data: [%{label: "Desktop", value: 45}, %{label: "Mobile", value: 55}]
             }
           ]) == :ok
  end

  test "rejects empty, negative, all-zero, or malformed data" do
    assert {:error, reason} = PieData.validate([])
    assert reason =~ "empty"

    assert {:error, _} = PieData.validate("invalid")
    assert {:error, _} = PieData.validate([%{label: "A", value: -5}])
    assert {:error, _} = PieData.validate([%{label: "A", value: 0}, %{label: "B", value: 0}])
    assert {:error, _} = PieData.validate([%{value: 10}])
    assert {:error, _} = PieData.validate([%{label: "A", value: "10"}])
    assert {:error, _} = PieData.validate([%{label: "A", value: 10, color: 123}])
    assert {:error, _} = PieData.validate([%{label: "A", value: 10, attrs: "invalid"}])

    assert {:error, _} =
             PieData.validate([%{name: "2025", data: [%{label: "A", value: 0}]}])

    assert {:error, _} =
             PieData.validate([%{name: "", data: [%{label: "A", value: 10}]}])
  end

  describe "normalize/1" do
    test "normalizes a flat list of slices into a single series" do
      assert PieData.normalize([
               %{name: "Desktop", value: 65, color: "#4E79A7"},
               %{label: "Mobile", value: 35}
             ]) == [
               %{
                 name: nil,
                 data: [
                   %{label: "Desktop", value: 65, color: "#4E79A7"},
                   %{label: "Mobile", value: 35}
                 ]
               }
             ]
    end

    test "normalizes a multi-series list" do
      data = [
        %{name: "2025", data: [%{label: "A", value: 60}, %{label: "B", value: 40}]},
        %{name: "2026", data: [%{label: "A", value: 50}, %{label: "B", value: 50}]}
      ]

      assert PieData.normalize(data) == data
    end
  end
end
