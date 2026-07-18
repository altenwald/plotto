defmodule Plotto.SVG.Renderer.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart
  alias Plotto.SVG.Renderer.LineChart, as: Renderer

  test "render/1 returns an <svg> root with a single <polyline>" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    polylines = Enum.filter(svg.children, &(&1.tag == "polyline"))
    assert length(polylines) == 1
  end

  test "the polyline has one x,y coordinate pair per data item" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)
    [polyline] = Enum.filter(svg.children, &(&1.tag == "polyline"))

    points = String.split(polyline.attrs["points"], " ")
    assert length(points) == 2
  end

  test "renders one <circle> per data item" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)
    circles = Enum.filter(svg.children, &(&1.tag == "circle"))
    assert length(circles) == 2
  end

  test "per-item :attrs are merged onto the corresponding <circle>" do
    chart =
      LineChart.new!([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}])

    svg = Renderer.render(chart)
    [circle] = Enum.filter(svg.children, &(&1.tag == "circle"))

    assert circle.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = LineChart.new!([%{label: "Jan", value: 10}], title: "Trend")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Trend"]} -> true
             _ -> false
           end)
  end
end
