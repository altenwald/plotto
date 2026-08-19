defmodule Plotto.SVG.Renderer.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart
  alias Plotto.SVG.Renderer.LineChart, as: Renderer

  @single_series [%{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "render/1 returns an <svg> root with a single <polyline>" do
    chart = LineChart.new!(@single_series)
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    polylines = Enum.filter(svg.children, &(&1.tag == "polyline"))
    assert length(polylines) == 1
  end

  test "the polyline has one x,y coordinate pair per data item" do
    chart = LineChart.new!(@single_series)
    svg = Renderer.render(chart)
    [polyline] = Enum.filter(svg.children, &(&1.tag == "polyline"))

    points = String.split(polyline.attrs["points"], " ")
    assert length(points) == 2
  end

  test "renders one <circle> per data item" do
    chart = LineChart.new!(@single_series)
    svg = Renderer.render(chart)
    circles = Enum.filter(svg.children, &(&1.tag == "circle"))
    assert length(circles) == 2
  end

  test "per-item :attrs are merged onto the corresponding <circle>" do
    data = [%{name: "Revenue", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}]
    chart = LineChart.new!(data)
    svg = Renderer.render(chart)
    [circle] = Enum.filter(svg.children, &(&1.tag == "circle"))

    assert circle.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = LineChart.new!(@single_series, title: "Trend")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Trend"]} -> true
             _ -> false
           end)
  end

  test "includes a legend swatch and text when :legend is set and the series is named" do
    chart = LineChart.new!(@single_series, legend: :bottom_left)
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Revenue"]} -> true
             _ -> false
           end)
  end

  test "does not include a legend when :legend is set but the series has no name" do
    data = [%{name: nil, data: [%{label: "Jan", value: 10}]}]
    chart = LineChart.new!(data, legend: :bottom_left)
    svg = Renderer.render(chart)

    swatch_width = to_string(Plotto.Theme.legend_swatch_size())
    refute Enum.any?(svg.children, &(&1.tag == "rect" and &1.attrs["width"] == swatch_width))
  end

  test "a bottom legend pushes the plot's bottom edge up by legend_row_height" do
    base_chart = LineChart.new!(@single_series)
    base_svg = Renderer.render(base_chart)
    [_y_axis, base_x_axis | _] = Enum.filter(base_svg.children, &(&1.tag == "line"))

    legend_chart = LineChart.new!(@single_series, legend: :bottom_right)
    legend_svg = Renderer.render(legend_chart)
    [_y_axis, legend_x_axis | _] = Enum.filter(legend_svg.children, &(&1.tag == "line"))

    base_y2 = elem(Float.parse(base_x_axis.attrs["y2"]), 0)
    legend_y2 = elem(Float.parse(legend_x_axis.attrs["y2"]), 0)

    assert legend_y2 == base_y2 - Plotto.Theme.legend_row_height()
  end

  test "a multi-series chart still renders (only the first series' line/points, no crash)" do
    data = [
      %{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    chart = LineChart.new!(data)
    svg = Renderer.render(chart)

    assert length(Enum.filter(svg.children, &(&1.tag == "polyline"))) == 1
    assert length(Enum.filter(svg.children, &(&1.tag == "circle"))) == 2
  end

  test "a multi-series chart with :legend set renders exactly one legend row (the first series')" do
    data = [
      %{name: "Revenue", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]},
      %{name: "Other", data: [%{label: "Jan", value: 2}]}
    ]

    chart = LineChart.new!(data, legend: :top_right)
    svg = Renderer.render(chart)

    texts =
      svg.children
      |> Enum.filter(&(&1.tag == "text"))
      |> Enum.filter(&(&1.children in [["Revenue"], ["Costs"], ["Other"]]))

    assert length(texts) == 1
    assert hd(texts).children == ["Revenue"]
  end
end
