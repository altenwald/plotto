defmodule Plotto.SVG.Renderer.CandlestickChartTest do
  use ExUnit.Case, async: true

  alias Plotto.CandlestickChart
  alias Plotto.SVG.Renderer.CandlestickChart, as: Renderer

  @data [
    %{label: "09:00", open: 100, high: 110, low: 95, close: 108}, # bullish
    %{label: "09:05", open: 108, high: 112, low: 98, close: 102}  # bearish
  ]

  test "render/1 returns an <svg> root with one wick line and one body rect per candle" do
    chart = CandlestickChart.new!(@data)
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    # 2 axis lines + 2 wicks = 4 lines
    lines = Enum.filter(svg.children, &(&1.tag == "line"))
    assert length(lines) == 4

    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    assert length(rects) == 2
  end

  test "bullish candle uses bullish_color and bearish candle uses bearish_color" do
    chart = CandlestickChart.new!(@data, bullish_color: "#00AA00", bearish_color: "#AA0000")
    svg = Renderer.render(chart)

    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    [bullish_rect, bearish_rect] = rects

    assert bullish_rect.attrs["fill"] == "#00AA00"
    assert bearish_rect.attrs["fill"] == "#AA0000"
  end

  test "wick line is centered and spans from high_y to low_y" do
    chart = CandlestickChart.new!(@data, width: 600, height: 400)
    svg = Renderer.render(chart)

    # First candle: high = 112 is max across all data, low = 95 is min across all data
    # High = 110, low = 95
    [_y_axis, _x_axis, wick1, _wick2] = Enum.filter(svg.children, &(&1.tag == "line"))
    [rect1, _rect2] = Enum.filter(svg.children, &(&1.tag == "rect"))

    wick_x1 = elem(Float.parse(wick1.attrs["x1"]), 0)
    wick_x2 = elem(Float.parse(wick1.attrs["x2"]), 0)
    rect_x = elem(Float.parse(rect1.attrs["x"]), 0)
    rect_w = elem(Float.parse(rect1.attrs["width"]), 0)

    # Wick is centered with respect to the candle body rect
    assert wick_x1 == wick_x2
    assert_in_delta wick_x1, rect_x + rect_w / 2, 0.01

    wick_y1 = elem(Float.parse(wick1.attrs["y1"]), 0)
    wick_y2 = elem(Float.parse(wick1.attrs["y2"]), 0)
    # y1 is high (higher price = smaller Y in SVG), y2 is low (lower price = larger Y in SVG)
    assert wick_y1 < wick_y2
  end

  test "doji candle (open == close) renders with minimal visible height" do
    doji_data = [
      %{label: "09:00", open: 100, high: 105, low: 95, close: 100}
    ]

    chart = CandlestickChart.new!(doji_data)
    svg = Renderer.render(chart)
    [rect] = Enum.filter(svg.children, &(&1.tag == "rect"))

    height = elem(Float.parse(rect.attrs["height"]), 0)
    assert height >= 1.0
  end

  test "per-item attrs are merged onto the candle rect" do
    data = [
      %{label: "09:00", open: 100, high: 105, low: 95, close: 102, attrs: %{"data-candle" => "1"}}
    ]

    chart = CandlestickChart.new!(data)
    svg = Renderer.render(chart)
    [rect] = Enum.filter(svg.children, &(&1.tag == "rect"))

    assert rect.attrs["data-candle"] == "1"
  end

  test "includes title when :title option is given" do
    chart = CandlestickChart.new!(@data, title: "BTC/USDT")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["BTC/USDT"]} -> true
             _ -> false
           end)
  end
end
