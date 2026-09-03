defmodule Plotto.SVG.Renderer.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart
  alias Plotto.SVG.Renderer.LineChart, as: Renderer

  @single_series [
    %{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}
  ]

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
    data = [
      %{name: "Revenue", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}
    ]

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

  test "a multi-series chart renders polylines and points for all series" do
    data = [
      %{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    chart = LineChart.new!(data)
    svg = Renderer.render(chart)

    assert length(Enum.filter(svg.children, &(&1.tag == "polyline"))) == 2
    assert length(Enum.filter(svg.children, &(&1.tag == "circle"))) == 4
  end

  test "a multi-series chart with :legend set renders legend rows for all series" do
    data = [
      %{name: "Revenue", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]},
      %{name: "Other", data: [%{label: "Jan", value: 2}]}
    ]

    chart = LineChart.new!(data, legend: :top_right)
    svg = Renderer.render(chart)

    texts =
      Enum.filter(
        svg.children,
        &(&1.tag == "text" and &1.children in [["Revenue"], ["Costs"], ["Other"]])
      )

    assert length(texts) == 3
    rendered_names = Enum.map(texts, &hd(&1.children))
    assert rendered_names == ["Revenue", "Costs", "Other"]
  end

  test "renders dashed polyline when series has dashed: true or stroke_dasharray" do
    data = [
      %{name: "Solid", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 20}]},
      %{
        name: "Dashed",
        dashed: true,
        data: [%{label: "Jan", value: 15}, %{label: "Feb", value: 25}]
      }
    ]

    chart = LineChart.new!(data)
    svg = Renderer.render(chart)

    polylines = Enum.filter(svg.children, &(&1.tag == "polyline"))
    assert length(polylines) == 2
    solid = Enum.at(polylines, 0)
    dashed = Enum.at(polylines, 1)

    refute Map.has_key?(solid.attrs, "stroke-dasharray")
    assert dashed.attrs["stroke-dasharray"] == "6,4"
  end

  test "renders series spanning subsets of categories across unified axis" do
    data = [
      %{name: "Short", data: [%{label: "1", value: 10}, %{label: "2", value: 20}]},
      %{
        name: "Long",
        data: [%{label: "1", value: 5}, %{label: "2", value: 15}, %{label: "3", value: 25}]
      }
    ]

    chart = LineChart.new!(data)
    svg = Renderer.render(chart)

    polylines = Enum.filter(svg.children, &(&1.tag == "polyline"))
    assert length(polylines) == 2
    short_polyline = Enum.at(polylines, 0)
    long_polyline = Enum.at(polylines, 1)

    assert length(String.split(short_polyline.attrs["points"], " ")) == 2
    assert length(String.split(long_polyline.attrs["points"], " ")) == 3
    assert length(Enum.filter(svg.children, &(&1.tag == "circle"))) == 5
  end

  test "renders negative values with points and polyline below the zero baseline" do
    data = [
      %{name: "Temperature", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: -10}]}
    ]

    chart = LineChart.new!(data, width: 600, height: 400)
    svg = Renderer.render(chart)

    margin = Plotto.Theme.margin()
    plot_height = 400 - margin.top - margin.bottom
    zero_y = margin.top + Plotto.Axis.linear_scale(0, -10, 10, plot_height)

    circles = Enum.filter(svg.children, &(&1.tag == "circle"))
    assert length(circles) == 2
    [pos_circle, neg_circle] = circles

    pos_cy = elem(Float.parse(pos_circle.attrs["cy"]), 0)
    neg_cy = elem(Float.parse(neg_circle.attrs["cy"]), 0)

    # Positive point is above zero baseline (smaller y in SVG)
    assert pos_cy < zero_y
    # Negative point is below zero baseline (larger y in SVG)
    assert neg_cy > zero_y
    # In symmetric domain [-10, 10], distances from zero_y are equal
    assert_in_delta zero_y - pos_cy, neg_cy - zero_y, 0.01
  end

  describe "label option" do
    test "label: true renders a text element immediately above each point" do
      chart = LineChart.new!(@single_series, label: true)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-point")
        )

      assert length(labels) == 2

      [l1, l2] = labels
      assert l1.children == ["Jan"]
      assert l2.children == ["Feb"]
      assert l1.attrs["text-anchor"] == "middle"
      assert l2.attrs["text-anchor"] == "middle"

      circles =
        Enum.filter(svg.children, &(&1.tag == "circle" and &1.attrs["class"] == "plotto-point"))

      [c1, c2] = circles

      # Label y is 7px above the circle's cy
      assert_in_delta String.to_float(l1.attrs["y"]), String.to_float(c1.attrs["cy"]) - 7, 0.01
      assert_in_delta String.to_float(l2.attrs["y"]), String.to_float(c2.attrs["cy"]) - 7, 0.01
    end

    test "label: :value renders formatted numeric values above each point" do
      chart = LineChart.new!(@single_series, label: :value)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-point")
        )

      assert length(labels) == 2
      assert Enum.map(labels, & &1.children) == [["10"], ["25"]]
    end

    test "label: custom function renders custom text above each point" do
      chart = LineChart.new!(@single_series, label: fn item -> "pt: #{item.value}" end)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-point")
        )

      assert length(labels) == 2
      assert Enum.map(labels, & &1.children) == [["pt: 10"], ["pt: 25"]]
    end

    test "label: false renders no point labels" do
      chart = LineChart.new!(@single_series, label: false)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-point")
        )

      assert labels == []
    end

    test "renders line swatches with solid or dashed styles in the legend" do
      data = [
        %{name: "Solid", data: [%{label: "Jan", value: 10}]},
        %{name: "Dashed", dashed: true, data: [%{label: "Jan", value: 20}]}
      ]

      chart = LineChart.new!(data, legend: :top_right)
      svg = Renderer.render(chart)

      swatches =
        Enum.filter(svg.children, &(&1.attrs["class"] == "plotto-legend-swatch"))

      assert length(swatches) == 2
      [solid_swatch, dashed_swatch] = swatches

      assert solid_swatch.tag == "line"
      refute Map.has_key?(solid_swatch.attrs, "stroke-dasharray")

      assert dashed_swatch.tag == "line"
      assert dashed_swatch.attrs["stroke-dasharray"] == "4,2"
    end

    test "renders dotted line and dotted legend swatch" do
      data = [
        %{name: "Dotted", dotted: true, data: [%{label: "Jan", value: 15}]}
      ]

      chart = LineChart.new!(data, legend: :top_right)
      svg = Renderer.render(chart)

      [polyline] = Enum.filter(svg.children, &(&1.tag == "polyline"))
      assert polyline.attrs["stroke-dasharray"] == "2,4"

      [swatch] = Enum.filter(svg.children, &(&1.attrs["class"] == "plotto-legend-swatch"))
      assert swatch.tag == "line"
      assert swatch.attrs["stroke-dasharray"] == "2,3"
    end

    test "configures stroke_width globally and per-series" do
      data = [
        %{name: "DefaultThick", data: [%{label: "Jan", value: 10}]},
        %{name: "CustomThick", stroke_width: 4, data: [%{label: "Jan", value: 20}]}
      ]

      chart = LineChart.new!(data, stroke_width: 2.5, legend: :top_right)
      svg = Renderer.render(chart)

      polylines = Enum.filter(svg.children, &(&1.tag == "polyline"))
      assert length(polylines) == 2
      [p1, p2] = polylines

      assert p1.attrs["stroke-width"] == "2.50"
      assert p2.attrs["stroke-width"] == "4"
    end
  end
end
