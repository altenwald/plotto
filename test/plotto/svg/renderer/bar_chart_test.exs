defmodule Plotto.SVG.Renderer.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart
  alias Plotto.SVG.Renderer.BarChart, as: Renderer

  test "render/1 returns an <svg> root with one <rect> per data item" do
    chart = BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    assert length(rects) == 2
  end

  test "each bar gets a fill color from the theme palette" do
    chart = BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    assert Enum.all?(rects, &String.starts_with?(&1.attrs["fill"], "#"))
  end

  test "per-item :attrs are merged onto the corresponding <rect>" do
    chart =
      BarChart.new!([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}])

    svg = Renderer.render(chart)
    [rect] = Enum.filter(svg.children, &(&1.tag == "rect"))

    assert rect.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = BarChart.new!([%{label: "Jan", value: 10}], title: "Sales")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end
end
