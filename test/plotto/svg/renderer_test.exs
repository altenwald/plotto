defmodule Plotto.SVG.RendererTest do
  use ExUnit.Case, async: true

  alias Plotto.{BarChart, LineChart}
  alias Plotto.SVG.Renderer

  test "dispatches BarChart to the bar chart renderer" do
    chart = BarChart.new!([%{name: "Sales", data: [%{label: "Jan", value: 10}]}])
    svg = Renderer.render(chart)
    assert svg.tag == "svg"
    assert Enum.any?(svg.children, &(&1.tag == "rect"))
  end

  test "dispatches LineChart to the line chart renderer" do
    chart = LineChart.new!([%{name: "Trend", data: [%{label: "Jan", value: 10}]}])
    svg = Renderer.render(chart)
    assert svg.tag == "svg"
    assert Enum.any?(svg.children, &(&1.tag == "polyline"))
  end

  test "dispatches CandlestickChart to the candlestick chart renderer" do
    chart =
      Plotto.CandlestickChart.new!([
        %{label: "09:00", open: 100, high: 105, low: 95, close: 102}
      ])

    svg = Renderer.render(chart)
    assert svg.tag == "svg"
    assert Enum.any?(svg.children, &(&1.tag == "rect"))
  end
end
