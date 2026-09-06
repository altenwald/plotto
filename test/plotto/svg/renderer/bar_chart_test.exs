defmodule Plotto.SVG.Renderer.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart
  alias Plotto.SVG.Renderer.BarChart, as: Renderer

  @single_series [
    %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}
  ]

  test "render/1 returns an <svg> root with one <rect> per data item for a single series" do
    chart = BarChart.new!(@single_series)
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    assert length(rects) == 2
    assert Enum.all?(rects, fn r -> Map.has_key?(r.attrs, "data-title") end)
  end

  test "all bars in a single series share one color (Theme.color(colors, 0))" do
    chart = BarChart.new!(@single_series)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    fills = rects |> Enum.map(& &1.attrs["fill"]) |> Enum.uniq()
    assert fills == [Plotto.Theme.color(Plotto.Theme.default_colors(), 0)]
  end

  test "per-item :attrs are merged onto the corresponding <rect>" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}
    ]

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
      Enum.filter(
        svg.children,
        &(&1.tag == "text" and &1.children in [["Sales"], ["Costs"]])
      )

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
               %{tag: "text", children: [^expected_name]} = text ->
                 text.attrs["text-anchor"] == "end"

               _ ->
                 false
             end)
    end
  end

  describe "stacked mode (:mode => :stacked)" do
    test "each segment in a stacked bar spans the full inner category width" do
      data = [
        %{name: "Sales", data: [%{label: "Jan", value: 10}]},
        %{name: "Costs", data: [%{label: "Jan", value: 5}]}
      ]

      chart = BarChart.new!(data, mode: :stacked, width: 600, height: 400)
      svg = Renderer.render(chart)
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))

      assert length(rects) == 2
      [first, second] = rects

      first_width = elem(Float.parse(first.attrs["width"]), 0)
      second_width = elem(Float.parse(second.attrs["width"]), 0)
      first_x = elem(Float.parse(first.attrs["x"]), 0)
      second_x = elem(Float.parse(second.attrs["x"]), 0)

      assert first_width == second_width
      assert first_x == second_x
    end

    test "segments in a category are stacked vertically on top of each other" do
      data = [
        %{name: "Sales", data: [%{label: "Jan", value: 20}]},
        %{name: "Costs", data: [%{label: "Jan", value: 30}]}
      ]

      chart = BarChart.new!(data, mode: :stacked, width: 600, height: 400)
      svg = Renderer.render(chart)
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))

      # Series 0 (Sales, 20) is at the bottom; Series 1 (Costs, 30) is stacked on top
      # In SVG, smaller y is higher up on screen
      [bottom_segment, top_segment] = rects

      bottom_y = elem(Float.parse(bottom_segment.attrs["y"]), 0)
      top_y = elem(Float.parse(top_segment.attrs["y"]), 0)
      top_height = elem(Float.parse(top_segment.attrs["height"]), 0)

      assert_in_delta top_y + top_height, bottom_y, 0.01
    end

    test "max_value in stacked mode scales to the maximum category sum across all series" do
      data = [
        %{name: "Sales", data: [%{label: "Jan", value: 30}, %{label: "Feb", value: 40}]},
        %{name: "Costs", data: [%{label: "Jan", value: 50}, %{label: "Feb", value: 60}]}
      ]

      chart = BarChart.new!(data, mode: :stacked, height: 400)
      svg = Renderer.render(chart)

      # In Feb, total is 40 + 60 = 100. Jan is 30 + 50 = 80.
      # The top of Feb's upper segment should reach y = margin.top (value == max_value => linear_scale == 0)
      margin = Plotto.Theme.margin()
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))
      min_y = rects |> Enum.map(&elem(Float.parse(&1.attrs["y"]), 0)) |> Enum.min()

      assert_in_delta min_y, margin.top, 0.01
    end

    test "per-item attrs are preserved on each stacked segment" do
      data = [
        %{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"data-id" => "s1"}}]},
        %{name: "Costs", data: [%{label: "Jan", value: 5, attrs: %{"data-id" => "s2"}}]}
      ]

      chart = BarChart.new!(data, mode: :stacked)
      svg = Renderer.render(chart)
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))

      data_ids = Enum.map(rects, & &1.attrs["data-id"])
      assert "s1" in data_ids
      assert "s2" in data_ids
    end
  end

  describe "negative values" do
    test "in grouped mode, negative bars extend downwards from the zero baseline" do
      data = [
        %{name: "Profit", data: [%{label: "Jan", value: 50}, %{label: "Feb", value: -30}]}
      ]

      chart = BarChart.new!(data, width: 600, height: 400)
      svg = Renderer.render(chart)
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))
      [pos_rect, neg_rect] = rects

      [_, x_axis_line] = Enum.filter(svg.children, &(&1.tag == "line"))
      zero_y = elem(Float.parse(x_axis_line.attrs["y1"]), 0)

      pos_y = elem(Float.parse(pos_rect.attrs["y"]), 0)
      pos_height = elem(Float.parse(pos_rect.attrs["height"]), 0)
      neg_y = elem(Float.parse(neg_rect.attrs["y"]), 0)
      neg_height = elem(Float.parse(neg_rect.attrs["height"]), 0)

      # Positive bar sits on top of the zero baseline (pos_y + pos_height == zero_y)
      assert_in_delta pos_y + pos_height, zero_y, 0.01
      # Negative bar hangs down from the zero baseline (neg_y == zero_y)
      assert_in_delta neg_y, zero_y, 0.01
      assert neg_height > 0
    end

    test "in stacked mode, positive bars stack upwards and negative bars stack downwards from zero" do
      data = [
        %{name: "Revenue", data: [%{label: "Jan", value: 40}]},
        %{name: "Expenses", data: [%{label: "Jan", value: -25}]}
      ]

      chart = BarChart.new!(data, mode: :stacked, width: 600, height: 400)
      svg = Renderer.render(chart)
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))
      [pos_rect, neg_rect] = rects

      [_, x_axis_line] = Enum.filter(svg.children, &(&1.tag == "line"))
      zero_y = elem(Float.parse(x_axis_line.attrs["y1"]), 0)

      pos_y = elem(Float.parse(pos_rect.attrs["y"]), 0)
      pos_height = elem(Float.parse(pos_rect.attrs["height"]), 0)
      neg_y = elem(Float.parse(neg_rect.attrs["y"]), 0)

      assert_in_delta pos_y + pos_height, zero_y, 0.01
      assert_in_delta neg_y, zero_y, 0.01
    end

    test "tooltip: :native renders <title> element inside <rect>" do
      chart = BarChart.new!(@single_series, tooltip: :native)
      svg = Renderer.render(chart)
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))

      assert Enum.all?(rects, fn r ->
               Enum.any?(r.children, &(&1.tag == "title")) and
                 not Map.has_key?(r.attrs, "data-title")
             end)
    end

    test "tooltip: false renders no tooltip attributes or children" do
      chart = BarChart.new!(@single_series, tooltip: false)
      svg = Renderer.render(chart)
      rects = Enum.filter(svg.children, &(&1.tag == "rect"))

      assert Enum.all?(rects, fn r ->
               r.children == [] and not Map.has_key?(r.attrs, "data-title")
             end)
    end

    test "tooltip: custom function formats data-title" do
      chart =
        BarChart.new!(@single_series,
          tooltip: fn item -> "Custom: #{item.label} = #{item.value}" end
        )

      svg = Renderer.render(chart)
      [r1, r2] = Enum.filter(svg.children, &(&1.tag == "rect"))

      assert r1.attrs["data-title"] == "Custom: Jan = 10"
      assert r2.attrs["data-title"] == "Custom: Feb = 25"
    end

    test "elements include semantic CSS classes" do
      chart = BarChart.new!(@single_series, title: "Title", legend: :top_right)
      svg = Renderer.render(chart)

      assert svg.attrs["class"] == "plotto-chart"
      rects = Enum.filter(svg.children, &(&1.tag == "rect" and &1.attrs["class"] == "plotto-bar"))
      assert length(rects) == 2
      assert Enum.any?(svg.children, &(&1.attrs["class"] == "plotto-title"))
      assert Enum.any?(svg.children, &(&1.attrs["class"] == "plotto-axis plotto-axis-y"))
      assert Enum.any?(svg.children, &(&1.attrs["class"] == "plotto-axis plotto-axis-x"))
      assert Enum.any?(svg.children, &(&1.attrs["class"] == "plotto-label plotto-label-x"))
      assert Enum.any?(svg.children, &(&1.attrs["class"] == "plotto-label plotto-label-y"))
      assert Enum.any?(svg.children, &(&1.attrs["class"] == "plotto-legend-swatch"))
      assert Enum.any?(svg.children, &(&1.attrs["class"] == "plotto-legend-text"))
    end
  end

  describe "label option" do
    test "label: true renders a text element immediately above each bar" do
      chart = BarChart.new!(@single_series, label: true)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-bar")
        )

      assert length(labels) == 2

      [l1, l2] = labels
      assert l1.children == ["Jan"]
      assert l2.children == ["Feb"]
      assert l1.attrs["text-anchor"] == "middle"
      assert l2.attrs["text-anchor"] == "middle"

      rects = Enum.filter(svg.children, &(&1.tag == "rect" and &1.attrs["class"] == "plotto-bar"))
      [r1, r2] = rects

      # Label y is 4px above the bar's top_y
      assert_in_delta String.to_float(l1.attrs["y"]), String.to_float(r1.attrs["y"]) - 4, 0.01
      assert_in_delta String.to_float(l2.attrs["y"]), String.to_float(r2.attrs["y"]) - 4, 0.01
    end

    test "label: :value renders formatted numeric values above each bar" do
      chart = BarChart.new!(@single_series, label: :value)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-bar")
        )

      assert length(labels) == 2
      assert Enum.map(labels, & &1.children) == [["10"], ["25"]]
    end

    test "label: custom function renders custom text above each bar" do
      chart = BarChart.new!(@single_series, label: fn item -> "#{item.label}: #{item.value}€" end)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-bar")
        )

      assert length(labels) == 2
      assert Enum.map(labels, & &1.children) == [["Jan: 10€"], ["Feb: 25€"]]
    end

    test "label: false renders no bar labels" do
      chart = BarChart.new!(@single_series, label: false)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-bar")
        )

      assert labels == []
    end

    test "label: true in stacked mode renders label above the stacked column" do
      data = [
        %{name: "A", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 20}]},
        %{name: "B", data: [%{label: "Jan", value: 15}, %{label: "Feb", value: 25}]}
      ]

      chart = BarChart.new!(data, mode: :stacked, label: true)
      svg = Renderer.render(chart)

      labels =
        Enum.filter(
          svg.children,
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-bar")
        )

      assert length(labels) == 2
      assert Enum.map(labels, & &1.children) == [["Jan"], ["Feb"]]
    end
  end

  describe "y_max, y_min, and guide lines" do
    test "y_max extends the Y axis and renders guide line" do
      chart =
        BarChart.new!(@single_series,
          y_max: 100,
          y_max_guide: {:solid, "#FF0000"}
        )

      svg = Renderer.render(chart)

      [guide] =
        Enum.filter(
          svg.children,
          &(&1.tag == "line" and
              &1.attrs["class"] == "plotto-guide-line plotto-guide-line-max")
        )

      assert guide.attrs["stroke"] == "#FF0000"
      refute Map.has_key?(guide.attrs, "stroke-dasharray")

      y_labels =
        svg.children
        |> Enum.filter(&(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-y"))
        |> Enum.map(&hd(&1.children))

      assert "100" in y_labels
    end

    test "y_min_guide renders min guide line with dashed style" do
      chart =
        BarChart.new!(@single_series,
          y_min: 0,
          y_min_guide: {:dashed, "#00FF00"}
        )

      svg = Renderer.render(chart)

      [guide] =
        Enum.filter(
          svg.children,
          &(&1.tag == "line" and
              &1.attrs["class"] == "plotto-guide-line plotto-guide-line-min")
        )

      assert guide.attrs["stroke"] == "#00FF00"
      assert guide.attrs["stroke-dasharray"] == "6,4"
    end
  end

  describe "value_suffix and value_prefix" do
    test "suffix: \"%\" adds % to y-axis labels and bar rect tooltips" do
      chart = BarChart.new!(@single_series, suffix: "%")
      svg = Renderer.render(chart)

      y_labels =
        svg.children
        |> Enum.filter(&(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-y"))
        |> Enum.map(&hd(&1.children))

      assert "0%" in y_labels
      assert "25%" in y_labels

      rects = Enum.filter(svg.children, &(&1.tag == "rect" and &1.attrs["class"] == "plotto-bar"))
      titles = Enum.map(rects, & &1.attrs["data-title"])

      assert titles == ["Sales: 10% (Jan)", "Sales: 25% (Feb)"]
    end

    test "suffix: \"%\" with label: :value displays % on bar top labels" do
      chart = BarChart.new!(@single_series, suffix: "%", label: :value)
      svg = Renderer.render(chart)

      bar_labels =
        svg.children
        |> Enum.filter(
          &(&1.tag == "text" and &1.attrs["class"] == "plotto-label plotto-label-bar")
        )
        |> Enum.map(&hd(&1.children))

      assert bar_labels == ["10%", "25%"]
    end
  end

  describe "x_guidelines and y_guidelines" do
    test "y_guidelines: true renders horizontal guidelines in bar chart" do
      chart = BarChart.new!(@single_series, y_guidelines: true)
      svg = Renderer.render(chart)

      guidelines =
        Enum.filter(
          svg.children,
          &(&1.tag == "line" and
              &1.attrs["class"] == "plotto-guideline plotto-guideline-y")
        )

      assert guidelines != []

      for g <- guidelines do
        assert g.attrs["stroke"] == Plotto.Theme.grid_color()
        assert g.attrs["stroke-dasharray"] == "2,4"
      end
    end

    test "x_guidelines: true renders vertical guidelines in bar chart" do
      chart = BarChart.new!(@single_series, x_guidelines: true)
      svg = Renderer.render(chart)

      guidelines =
        Enum.filter(
          svg.children,
          &(&1.tag == "line" and
              &1.attrs["class"] == "plotto-guideline plotto-guideline-x")
        )

      assert length(guidelines) == 2
    end
  end
end
