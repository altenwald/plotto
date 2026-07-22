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

  test "includes a legend swatch and text when :legend and :name are set" do
    chart =
      BarChart.new!([%{label: "Jan", value: 10}], name: "Sales", legend: :top_right)

    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end

  test "does not include a legend when :legend is set but :name is nil" do
    chart = BarChart.new!([%{label: "Jan", value: 10}], legend: :top_right)
    svg = Renderer.render(chart)

    refute Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end

  test "a top legend pushes the y-axis line down by legend_row_height" do
    base_chart = BarChart.new!([%{label: "Jan", value: 10}])
    base_svg = Renderer.render(base_chart)
    [base_y_axis | _] = Enum.filter(base_svg.children, &(&1.tag == "line"))

    legend_chart =
      BarChart.new!([%{label: "Jan", value: 10}], name: "Sales", legend: :top_left)

    legend_svg = Renderer.render(legend_chart)
    [legend_y_axis | _] = Enum.filter(legend_svg.children, &(&1.tag == "line"))

    # Float.parse/1, not String.to_float/1 — margin.top-derived attrs format as plain
    # integer strings (e.g. "40"), which String.to_float/1 rejects. See the note in
    # Task 4's shared_test.exs additions.
    base_y1 = elem(Float.parse(base_y_axis.attrs["y1"]), 0)
    legend_y1 = elem(Float.parse(legend_y_axis.attrs["y1"]), 0)

    assert legend_y1 == base_y1 + Plotto.Theme.legend_row_height()
  end

  test ":bottom_right legend renders with a realistic multi-bar, custom-palette chart" do
    data = [
      %{label: "Jan", value: 10},
      %{label: "Feb", value: 25},
      %{label: "Mar", value: 18},
      %{label: "Apr", value: 30}
    ]

    colors = ["#111111", "#222222", "#333333"]

    chart =
      BarChart.new!(data, name: "Sales", legend: :bottom_right, colors: colors)

    svg = Renderer.render(chart)

    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    # 4 bars + 1 legend swatch
    assert length(rects) == 5

    # Distinguish the legend swatch from bars by its fixed, small width — with 3
    # colors cycled across 4 bars, more than one bar could coincidentally share the
    # legend's color (Theme.color(colors, 0)), so filtering by color alone isn't
    # reliable here.
    swatch_width = to_string(Plotto.Theme.legend_swatch_size())
    [legend_swatch] = Enum.filter(rects, &(&1.attrs["width"] == swatch_width))
    assert legend_swatch.attrs["fill"] == Enum.at(colors, 0)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} = text -> text.attrs["text-anchor"] == "end"
             _ -> false
           end)
  end
end
