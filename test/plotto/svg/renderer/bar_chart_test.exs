defmodule Plotto.SVG.Renderer.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart
  alias Plotto.SVG.Renderer.BarChart, as: Renderer

  @single_series [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "render/1 returns an <svg> root with one <rect> per data item for a single series" do
    chart = BarChart.new!(@single_series)
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    assert length(rects) == 2
  end

  test "all bars in a single series share one color (Theme.color(colors, 0))" do
    chart = BarChart.new!(@single_series)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    fills = rects |> Enum.map(& &1.attrs["fill"]) |> Enum.uniq()
    assert fills == [Plotto.Theme.color(Plotto.Theme.default_colors(), 0)]
  end

  test "per-item :attrs are merged onto the corresponding <rect>" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}]
    chart = BarChart.new!(data)
    svg = Renderer.render(chart)
    [rect] = Enum.filter(svg.children, &(&1.tag == "rect"))

    assert rect.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = BarChart.new!(@single_series, title: "Monthly")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Monthly"]} -> true
             _ -> false
           end)
  end

  test "includes a legend swatch and text when :legend is set and the series is named" do
    chart = BarChart.new!(@single_series, legend: :top_right)
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end

  test "does not include a legend when :legend is set but the (single) series has no name" do
    data = [%{name: nil, data: [%{label: "Jan", value: 10}]}]
    chart = BarChart.new!(data, legend: :top_right)
    svg = Renderer.render(chart)

    swatch_width = to_string(Plotto.Theme.legend_swatch_size())
    refute Enum.any?(svg.children, &(&1.tag == "rect" and &1.attrs["width"] == swatch_width))
  end

  test "a top legend pushes the y-axis line down by legend_row_height" do
    base_chart = BarChart.new!(@single_series)
    base_svg = Renderer.render(base_chart)
    [base_y_axis | _] = Enum.filter(base_svg.children, &(&1.tag == "line"))

    legend_chart = BarChart.new!(@single_series, legend: :top_left)
    legend_svg = Renderer.render(legend_chart)
    [legend_y_axis | _] = Enum.filter(legend_svg.children, &(&1.tag == "line"))

    base_y1 = elem(Float.parse(base_y_axis.attrs["y1"]), 0)
    legend_y1 = elem(Float.parse(legend_y_axis.attrs["y1"]), 0)

    assert legend_y1 == base_y1 + Plotto.Theme.legend_row_height()
  end

  test "renders n_series bars per category for a multi-series chart" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    chart = BarChart.new!(data)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    # 2 categories x 2 series = 4 bars
    assert length(rects) == 4
  end

  test "each series' bars share one color, distinct per series" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    colors = ["#111111", "#222222"]
    chart = BarChart.new!(data, colors: colors)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    fills = rects |> Enum.map(& &1.attrs["fill"]) |> Enum.uniq() |> Enum.sort()
    assert fills == Enum.sort(colors)
  end

  test "grouped bars within one category are flush against each other, no gap" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    chart = BarChart.new!(data, width: 600, height: 400)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    [first, second] =
      Enum.sort_by(rects, &elem(Float.parse(&1.attrs["x"]), 0))

    first_x = elem(Float.parse(first.attrs["x"]), 0)
    first_width = elem(Float.parse(first.attrs["width"]), 0)
    second_x = elem(Float.parse(second.attrs["x"]), 0)

    assert_in_delta first_x + first_width, second_x, 0.01
  end

  test "max_value spans all series, not just the first" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 90}]}
    ]

    chart = BarChart.new!(data, height: 400)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    heights = rects |> Enum.map(&elem(Float.parse(&1.attrs["height"]), 0)) |> Enum.sort()
    assert Enum.at(heights, 1) > Enum.at(heights, 0) * 2
  end

  test "renders a legend row per series, in series order" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    chart = BarChart.new!(data, legend: :top_left)
    svg = Renderer.render(chart)

    texts =
      svg.children
      |> Enum.filter(&(&1.tag == "text"))
      |> Enum.filter(&(&1.children in [["Sales"], ["Costs"]]))

    assert length(texts) == 2
    [sales_text] = Enum.filter(texts, &(&1.children == ["Sales"]))
    [costs_text] = Enum.filter(texts, &(&1.children == ["Costs"]))

    sales_y = elem(Float.parse(sales_text.attrs["y"]), 0)
    costs_y = elem(Float.parse(costs_text.attrs["y"]), 0)

    assert sales_y < costs_y
  end

  test ":bottom_right legend renders correctly with a realistic multi-series, multi-category chart" do
    data = [
      %{
        name: "Sales",
        data: [
          %{label: "Jan", value: 10},
          %{label: "Feb", value: 25},
          %{label: "Mar", value: 18},
          %{label: "Apr", value: 30}
        ]
      },
      %{
        name: "Costs",
        data: [
          %{label: "Jan", value: 5},
          %{label: "Feb", value: 8},
          %{label: "Mar", value: 6},
          %{label: "Apr", value: 9}
        ]
      }
    ]

    colors = ["#111111", "#222222"]
    chart = BarChart.new!(data, legend: :bottom_right, colors: colors)
    svg = Renderer.render(chart)

    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    # 4 categories x 2 series = 8 bars, + 2 legend swatches
    assert length(rects) == 10

    swatch_width = to_string(Plotto.Theme.legend_swatch_size())
    swatches = Enum.filter(rects, &(&1.attrs["width"] == swatch_width))
    assert length(swatches) == 2

    for expected_name <- ["Sales", "Costs"] do
      assert Enum.any?(svg.children, fn
               %{tag: "text", children: [^expected_name]} = text -> text.attrs["text-anchor"] == "end"
               _ -> false
             end)
    end
  end
end
