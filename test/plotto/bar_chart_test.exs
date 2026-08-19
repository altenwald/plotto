defmodule Plotto.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart

  @valid_data [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "new/2 returns {:ok, chart} for valid data" do
    assert {:ok, %BarChart{data: @valid_data}} = BarChart.new(@valid_data)
  end

  test "new/2 applies default opts when none given" do
    {:ok, chart} = BarChart.new(@valid_data)
    assert chart.opts.width == Plotto.Theme.default_width()
  end

  test "new/2 returns {:error, reason} for invalid data" do
    assert {:error, _reason} = BarChart.new([])
  end

  test "new!/2 returns the chart struct for valid data" do
    assert %BarChart{} = BarChart.new!(@valid_data, title: "Sales")
  end

  test "new!/2 raises ArgumentError for invalid data" do
    assert_raise ArgumentError, fn -> BarChart.new!([]) end
  end

  test "new/2 returns {:error, reason} for an invalid legend position" do
    assert {:error, reason} = BarChart.new(@valid_data, legend: :middle)
    assert reason =~ "invalid legend position"
  end

  test "new!/2 raises ArgumentError for an invalid legend position" do
    assert_raise ArgumentError, fn -> BarChart.new!(@valid_data, legend: :middle) end
  end

  test "new/2 accepts a valid :legend position" do
    assert {:ok, chart} = BarChart.new(@valid_data, legend: :top_right)
    assert chart.opts.legend == :top_right
  end

  test "new/2 returns {:error, reason} for a nil series name with 2+ series" do
    data = [
      %{name: nil, data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    assert {:error, reason} = BarChart.new(data)
    assert reason =~ "name is required"
  end
end
