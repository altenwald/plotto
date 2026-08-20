defmodule Plotto.CandlestickChartTest do
  use ExUnit.Case, async: true

  alias Plotto.CandlestickChart

  @valid_data [
    %{label: "09:00", open: 100, high: 105, low: 95, close: 102},
    %{label: "09:05", open: 102, high: 108, low: 101, close: 107}
  ]

  test "new/2 returns {:ok, chart} for valid flat data" do
    assert {:ok, %CandlestickChart{data: [%{name: nil, data: @valid_data}]}} =
             CandlestickChart.new(@valid_data)
  end

  test "new/2 returns {:ok, chart} for valid series data" do
    series = [%{name: "AAPL", data: @valid_data}]
    assert {:ok, %CandlestickChart{data: ^series}} = CandlestickChart.new(series)
  end

  test "new/2 applies default opts when none given" do
    {:ok, chart} = CandlestickChart.new(@valid_data)
    assert chart.opts.width == Plotto.Theme.default_width()
    assert chart.opts.bullish_color == Plotto.Theme.bullish_color()
    assert chart.opts.bearish_color == Plotto.Theme.bearish_color()
  end

  test "new/2 returns {:error, reason} for invalid data" do
    assert {:error, _reason} = CandlestickChart.new([])
  end

  test "new!/2 returns the chart struct for valid data" do
    assert %CandlestickChart{} = CandlestickChart.new!(@valid_data, title: "AAPL")
  end

  test "new!/2 raises ArgumentError for invalid data" do
    assert_raise ArgumentError, fn -> CandlestickChart.new!([]) end
  end

  test "new/2 accepts custom colors" do
    {:ok, chart} =
      CandlestickChart.new(@valid_data, bullish_color: "#00FF00", bearish_color: "#FF0000")

    assert chart.opts.bullish_color == "#00FF00"
    assert chart.opts.bearish_color == "#FF0000"
  end
end
