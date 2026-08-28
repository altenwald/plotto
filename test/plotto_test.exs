defmodule PlottoTest do
  use ExUnit.Case, async: true

  doctest Plotto
  doctest Plotto.BarChart
  doctest Plotto.LineChart
  doctest Plotto.CandlestickChart

  alias Plotto.{BarChart, CandlestickChart, LineChart}

  @single_series [
    %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}
  ]

  test "to_svg/1 returns {:ok, svg_string} for a bar chart" do
    chart = BarChart.new!(@single_series)
    assert {:ok, svg} = Plotto.to_svg(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<rect"
  end

  test "to_svg!/1 returns the svg string directly for a line chart" do
    chart = LineChart.new!(@single_series)
    svg = Plotto.to_svg!(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<polyline"
  end

  test "per-item attrs pass through end to end into the SVG output" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}
    ]

    chart = BarChart.new!(data)

    svg = Plotto.to_svg!(chart)
    assert svg =~ ~s(phx-click="select")
  end

  test "labels with special characters are escaped end to end" do
    data = [%{name: "Sales", data: [%{label: "<script>", value: 10}]}]
    chart = BarChart.new!(data)
    svg = Plotto.to_svg!(chart)
    refute svg =~ "<script>"
    assert svg =~ "&lt;script&gt;"
  end

  test "a bar chart with a legend renders the series name end to end in SVG" do
    chart = BarChart.new!(@single_series, legend: :top_right)

    svg = Plotto.to_svg!(chart)
    assert svg =~ "Sales"
  end

  test "all bars in a single-series chart share one color end to end" do
    data = [%{name: "Sales", data: for(i <- 0..6, do: %{label: "Item#{i}", value: i + 1})}]

    chart = BarChart.new!(data)
    svg = Plotto.to_svg!(chart)

    fills =
      Regex.scan(~r/<rect[^>]*fill="(#[0-9A-Fa-f]{6})"/, svg)
      |> Enum.map(fn [_, fill] -> fill end)

    assert Enum.uniq(fills) == [Plotto.Theme.color(Plotto.Theme.default_colors(), 0)]
  end

  test "each series gets a distinct color end to end for a multi-series bar chart" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    chart = BarChart.new!(data, colors: ["#111111", "#222222"])
    svg = Plotto.to_svg!(chart)

    assert svg =~ "#111111"
    assert svg =~ "#222222"
  end

  test "custom :width and :height thread through new!/2 into the rendered SVG" do
    chart = BarChart.new!(@single_series, width: 800, height: 500)

    svg = Plotto.to_svg!(chart)

    assert svg =~ ~s(width="800")
    assert svg =~ ~s(height="500")
    assert svg =~ ~s(viewBox="0 0 800 500")
  end

  test "to_svg/1 returns {:error, reason} for a value that isn't a supported chart" do
    assert {:error, reason} = Plotto.to_svg(%{not: "a chart"})
    assert is_binary(reason)
  end

  test "to_svg!/1 raises ArgumentError for a value that isn't a supported chart" do
    assert_raise ArgumentError, fn -> Plotto.to_svg!(%{not: "a chart"}) end
  end

  describe "to_png/1 and to_png!/1" do
    @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

    test "to_png/1 returns {:ok, png_binary} for a bar chart, at final (non-supersampled) dimensions" do
      chart = BarChart.new!(@single_series, width: 100, height: 80)

      assert {:ok, png} = Plotto.to_png(chart)

      assert binary_part(png, 0, 8) == @png_signature
      <<@png_signature, _length::32, "IHDR", width::32, height::32, _rest::binary>> = png
      assert width == 100
      assert height == 80
    end

    test "to_png!/1 returns the png binary directly for a line chart" do
      chart = LineChart.new!(@single_series)
      png = Plotto.to_png!(chart)

      assert binary_part(png, 0, 8) == @png_signature
    end

    test "to_png/1 returns {:error, reason} for a value that isn't a supported chart" do
      assert {:error, reason} = Plotto.to_png(%{not: "a chart"})
      assert is_binary(reason)
    end

    test "to_png!/1 raises ArgumentError for a value that isn't a supported chart" do
      assert_raise ArgumentError, fn -> Plotto.to_png!(%{not: "a chart"}) end
    end
  end

  describe "to_png!/1 end-to-end" do
    @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

    test "a bar chart with a title and custom colors renders without error" do
      data = [
        %{
          name: "Sales",
          data: [
            %{label: "Jan", value: 10},
            %{label: "Feb", value: 25},
            %{label: "Mar", value: 18},
            %{label: "Apr", value: 30}
          ]
        }
      ]

      chart = BarChart.new!(data, title: "Sales", colors: ["#4E79A7"])
      png = Plotto.to_png!(chart)

      assert byte_size(png) > 0
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a chart with a label containing accented characters renders without error" do
      data = [%{name: "Sales", data: [%{label: "Niño", value: 10}, %{label: "café", value: 15}]}]
      chart = BarChart.new!(data, title: "Tendencias")

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a bar chart with a legend renders without error" do
      chart = BarChart.new!(@single_series, legend: :bottom_left)

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a line chart with a legend renders without error" do
      data = [%{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]
      chart = LineChart.new!(data, legend: :top_left)

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a multi-series bar chart with a legend renders without error" do
      data = [
        %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
        %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
      ]

      chart = BarChart.new!(data, title: "Sales vs Costs", legend: :top_right)
      png = Plotto.to_png!(chart)

      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a stacked bar chart renders both SVG and PNG end-to-end without error" do
      data = [
        %{name: "Sales", data: [%{label: "Jan", value: 40}, %{label: "Feb", value: 60}]},
        %{name: "Costs", data: [%{label: "Jan", value: 20}, %{label: "Feb", value: 30}]}
      ]

      chart =
        BarChart.new!(data, mode: :stacked, title: "Stacked Sales vs Costs", legend: :top_left)

      assert {:ok, svg} = Plotto.to_svg(chart)
      assert svg =~ "<rect"
      assert svg =~ "Sales"
      assert svg =~ "Costs"

      assert {:ok, png} = Plotto.to_png(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a chart with negative and mixed values renders SVG and PNG end-to-end" do
      bar_data = [
        %{name: "Profit", data: [%{label: "Jan", value: 50}, %{label: "Feb", value: -20}]}
      ]

      bar_chart = BarChart.new!(bar_data, title: "Profit/Loss")
      assert {:ok, bar_svg} = Plotto.to_svg(bar_chart)
      assert bar_svg =~ "<rect"
      assert {:ok, bar_png} = Plotto.to_png(bar_chart)
      assert binary_part(bar_png, 0, 8) == @png_signature

      line_data = [
        %{name: "Temperature", data: [%{label: "Jan", value: -5}, %{label: "Feb", value: 15}]}
      ]

      line_chart = LineChart.new!(line_data, title: "Temperature")
      assert {:ok, line_svg} = Plotto.to_svg(line_chart)
      assert line_svg =~ "<polyline"
      assert {:ok, line_png} = Plotto.to_png(line_chart)
      assert binary_part(line_png, 0, 8) == @png_signature
    end

    test "a candlestick chart renders SVG and PNG end-to-end without error" do
      candle_data = [
        %{label: "09:00", open: 100, high: 108, low: 95, close: 104},
        %{label: "09:05", open: 104, high: 106, low: 92, close: 96}
      ]

      chart = CandlestickChart.new!(candle_data, title: "ETH/USDT")
      assert {:ok, svg} = Plotto.to_svg(chart)
      assert svg =~ "<line"
      assert svg =~ "<rect"
      assert svg =~ "ETH/USDT"

      assert {:ok, png} = Plotto.to_png(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "charts with label: true render SVG labels and PNG without error" do
      data = [
        %{name: "Revenue", data: [%{label: "Q1", value: 100}, %{label: "Q2", value: 150}]}
      ]

      bar_chart = BarChart.new!(data, label: true)
      assert {:ok, bar_svg} = Plotto.to_svg(bar_chart)
      assert bar_svg =~ "plotto-label plotto-label-bar"
      assert bar_svg =~ "Q1"
      assert {:ok, bar_png} = Plotto.to_png(bar_chart)
      assert binary_part(bar_png, 0, 8) == @png_signature

      line_chart = LineChart.new!(data, label: true)
      assert {:ok, line_svg} = Plotto.to_svg(line_chart)
      assert line_svg =~ "plotto-label plotto-label-point"
      assert line_svg =~ "Q1"
      assert {:ok, line_png} = Plotto.to_png(line_chart)
      assert binary_part(line_png, 0, 8) == @png_signature
    end
  end
end
