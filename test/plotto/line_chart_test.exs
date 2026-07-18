defmodule Plotto.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart

  @valid_data [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]

  test "new/2 returns {:ok, chart} for valid data" do
    assert {:ok, %LineChart{data: @valid_data}} = LineChart.new(@valid_data)
  end

  test "new/2 returns {:error, reason} for invalid data" do
    assert {:error, _reason} = LineChart.new([])
  end

  test "new!/2 returns the chart struct for valid data" do
    assert %LineChart{} = LineChart.new!(@valid_data, title: "Trend")
  end

  test "new!/2 raises ArgumentError for invalid data" do
    assert_raise ArgumentError, fn -> LineChart.new!([]) end
  end
end
