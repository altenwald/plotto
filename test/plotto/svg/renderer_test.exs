defmodule Plotto.SVG.RendererTest do
  use ExUnit.Case, async: true

  alias Plotto.{BarChart, LineChart}
  alias Plotto.SVG.Renderer

  test "dispatches BarChart to the bar chart renderer" do
    chart = BarChart.new!([%{label: "Jan", value: 10}])
    svg = Renderer.render(chart)
    assert svg.tag == "svg"
    assert Enum.any?(svg.children, &(&1.tag == "rect"))
  end

  test "dispatches LineChart to the line chart renderer" do
    chart = LineChart.new!([%{label: "Jan", value: 10}])
    svg = Renderer.render(chart)
    assert svg.tag == "svg"
    assert Enum.any?(svg.children, &(&1.tag == "polyline"))
  end
end
