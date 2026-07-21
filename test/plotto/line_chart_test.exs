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

  test "new/2 returns {:error, reason} for an invalid legend position" do
    assert {:error, reason} = LineChart.new(@valid_data, legend: :middle)
    assert reason =~ "invalid legend position"
  end

  test "new!/2 raises ArgumentError for an invalid legend position" do
    assert_raise ArgumentError, fn -> LineChart.new!(@valid_data, legend: :middle) end
  end

  test "new/2 accepts a valid :legend position together with :name" do
    assert {:ok, chart} = LineChart.new(@valid_data, name: "Trend", legend: :top_right)
    assert chart.opts.name == "Trend"
    assert chart.opts.legend == :top_right
  end
end
