defmodule Plotto.SVG.Renderer.SharedTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared

  test "svg_root/3 builds a root <svg> element with viewBox and given children" do
    child = Element.new("rect")
    root = Shared.svg_root(600, 400, [child])

    assert root.tag == "svg"
    assert root.attrs["viewBox"] == "0 0 600 400"
    assert root.attrs["width"] == "600"
    assert root.attrs["height"] == "400"
    assert root.children == [child]
  end

  test "title_elements/2 returns [] when title is nil" do
    assert Shared.title_elements(nil, 600) == []
  end

  test "title_elements/2 returns a centered <text> element when title is given" do
    [title] = Shared.title_elements("Sales", 600)
    assert title.tag == "text"
    assert title.attrs["text-anchor"] == "middle"
    assert title.children == ["Sales"]
  end

  test "axis_elements/5 returns one axis line pair plus one text label per band and per tick" do
    bands = Plotto.Axis.categorical_scale(["Jan", "Feb"], 200)
    margin = Plotto.Theme.margin()

    elements = Shared.axis_elements(bands, margin, 200, 100, 10)

    lines = Enum.filter(elements, &(&1.tag == "line"))
    texts = Enum.filter(elements, &(&1.tag == "text"))

    assert length(lines) == 2
    # 2 x-axis labels (Jan, Feb) + 6 y-axis tick labels (0, 2, 4, 6, 8, 10)
    assert length(texts) == 8
  end

  test "axis_elements/5 renders whole-number tick labels without trailing decimals despite float imprecision" do
    bands = Plotto.Axis.categorical_scale(["Jan"], 100)
    margin = Plotto.Theme.margin()

    # Axis.ticks(29.999999999999996) includes a last tick of 29.999999999999996,
    # which is mathematically 30 but not == trunc(30) due to float division
    # imprecision. format_tick/1 must round before comparing so this still
    # renders as "30", not "30.00".
    elements = Shared.axis_elements(bands, margin, 100, 100, 29.999999999999996)

    tick_labels =
      elements
      |> Enum.filter(&(&1.tag == "text"))
      |> Enum.map(fn %{children: [text]} -> text end)

    assert "30" in tick_labels
    refute "30.00" in tick_labels
  end

  test "axis_elements/6 draws the horizontal baseline at the zero Y position and ticks spanning negative to positive" do
    bands = Plotto.Axis.categorical_scale(["Jan"], 100)
    margin = Plotto.Theme.margin()

    # Domain [-60, 60], plot_height = 200. Zero is at y = margin.top + 100
    elements = Shared.axis_elements(bands, margin, 100, 200, -60, 60)
    lines = Enum.filter(elements, &(&1.tag == "line"))

    # Horizontal baseline is the second line (y1 == y2)
    [_, x_axis_line] = lines
    expected_zero_y = margin.top + 100.0
    assert elem(Float.parse(x_axis_line.attrs["y1"]), 0) == expected_zero_y
    assert elem(Float.parse(x_axis_line.attrs["y2"]), 0) == expected_zero_y

    tick_labels =
      elements
      |> Enum.filter(&(&1.tag == "text"))
      |> Enum.map(fn %{children: [text]} -> text end)

    assert "-50" in tick_labels
    assert "0" in tick_labels
    assert "50" in tick_labels
  end

  describe "effective_margin/3" do
    @margin Plotto.Theme.margin()
    @row_height Plotto.Theme.legend_row_height()

    test "returns the margin unchanged when legend is nil" do
      assert Shared.effective_margin(@margin, nil, [{"Sales", "#4E79A7"}]) == @margin
    end

    test "returns the margin unchanged when entries is empty" do
      assert Shared.effective_margin(@margin, :top_left, []) == @margin
    end

    test "returns the margin unchanged for a single nil-named entry (nothing to draw)" do
      assert Shared.effective_margin(@margin, :top_left, [{nil, "#4E79A7"}]) == @margin
    end

    test "adds legend_row_height * n to margin.top for :top_left/:top_right" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]

      for position <- [:top_left, :top_right] do
        result = Shared.effective_margin(@margin, position, entries)
        assert result.top == @margin.top + @row_height * 2
        assert result.bottom == @margin.bottom
      end
    end

    test "adds legend_row_height * n to margin.bottom for :bottom_left/:bottom_right" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}, {"Other", "#E15759"}]

      for position <- [:bottom_left, :bottom_right] do
        result = Shared.effective_margin(@margin, position, entries)
        assert result.bottom == @margin.bottom + @row_height * 3
        assert result.top == @margin.top
      end
    end
  end

  describe "legend_elements/5" do
    @margin Plotto.Theme.margin()

    test "returns [] when legend is nil" do
      assert Shared.legend_elements([{"Sales", "#4E79A7"}], nil, @margin, 600, 400) == []
    end

    test "returns [] when entries is empty" do
      assert Shared.legend_elements([], :top_left, @margin, 600, 400) == []
    end

    test "returns [] for a single nil-named entry (nothing to draw)" do
      assert Shared.legend_elements([{nil, "#4E79A7"}], :top_left, @margin, 600, 400) == []
    end

    test "returns [] for a legend atom outside the four valid positions (defensive)" do
      assert Shared.legend_elements([{"Sales", "#4E79A7"}], :middle, @margin, 600, 400) == []
    end

    test "returns one swatch+text pair for a single entry" do
      [swatch, text] =
        Shared.legend_elements([{"Sales", "#4E79A7"}], :top_right, @margin, 600, 400)

      assert swatch.tag == "rect"
      assert swatch.attrs["fill"] == "#4E79A7"
      assert text.tag == "text"
      assert text.attrs["text-anchor"] == "end"
      assert text.children == ["Sales"]
    end

    test "returns N swatch+text pairs for N entries" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}, {"Other", "#E15759"}]
      elements = Shared.legend_elements(entries, :top_left, @margin, 600, 400)

      assert length(elements) == 6
      texts = elements |> Enum.filter(&(&1.tag == "text")) |> Enum.map(& &1.children)
      assert texts == [["Sales"], ["Costs"], ["Other"]]
    end

    test "row 0 is topmost for both :top_* and :bottom_* positions" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]

      for position <- [:top_left, :bottom_left] do
        margin = Shared.effective_margin(@margin, position, entries)

        [row0_swatch, _row0_text, row1_swatch, _row1_text] =
          Shared.legend_elements(entries, position, margin, 600, 400)

        row0_y = elem(Float.parse(row0_swatch.attrs["y"]), 0)
        row1_y = elem(Float.parse(row1_swatch.attrs["y"]), 0)

        assert row0_y < row1_y
      end
    end

    test "bottom-position legend (N entries) does not overlap the x-axis tick labels" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]
      margin = Shared.effective_margin(@margin, :bottom_left, entries)
      plot_width = 600 - margin.left - margin.right
      plot_height = 400 - margin.top - margin.bottom
      bands = Plotto.Axis.categorical_scale(["Jan", "Feb"], plot_width)

      axis = Shared.axis_elements(bands, margin, plot_width, plot_height, 10)

      max_tick_label_y =
        axis
        |> Enum.filter(&(&1.tag == "text"))
        |> Enum.map(&elem(Float.parse(&1.attrs["y"]), 0))
        |> Enum.max()

      min_swatch_y =
        entries
        |> then(&Shared.legend_elements(&1, :bottom_left, margin, 600, 400))
        |> Enum.filter(&(&1.tag == "rect"))
        |> Enum.map(&elem(Float.parse(&1.attrs["y"]), 0))
        |> Enum.min()

      assert min_swatch_y > max_tick_label_y
    end

    test ":right_top expands margin.right and places swatches to the right of plot area" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]
      margin = Shared.effective_margin(@margin, :right_top, entries)

      assert margin.right > @margin.right
      assert margin.top == @margin.top

      elements = Shared.legend_elements(entries, :right_top, margin, 600, 400)
      [swatch0, text0, swatch1, _text1] = elements

      swatch0_x = elem(Float.parse(swatch0.attrs["x"]), 0)
      plot_right = 600 - margin.right
      assert swatch0_x > plot_right
      assert text0.attrs["text-anchor"] == "start"

      swatch0_y = elem(Float.parse(swatch0.attrs["y"]), 0)
      swatch1_y = elem(Float.parse(swatch1.attrs["y"]), 0)
      assert swatch0_y < swatch1_y
    end

    test ":left_top expands margin.left and places swatches to the far left" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]
      margin = Shared.effective_margin(@margin, :left_top, entries)

      assert margin.left > @margin.left
      assert margin.top == @margin.top

      elements = Shared.legend_elements(entries, :left_top, margin, 600, 400)
      [swatch0, text0, _swatch1, _text1] = elements

      swatch0_x = elem(Float.parse(swatch0.attrs["x"]), 0)
      assert swatch0_x == 8
      assert text0.attrs["text-anchor"] == "start"
    end

    test "expands left margin dynamically when Y-axis ticks are large numbers" do
      ticks = [0, 500_000, 1_000_000, 1_500_000]
      margin = Shared.effective_margin(@margin, nil, [], ticks, ["A", "B"])

      assert margin.left > @margin.left
      assert margin.left >= 70
    end

    test "expands bottom margin and rotates X labels when labels are longer than 3 characters" do
      labels = ["2026-08-01", "2026-08-02", "2026-08-03"]
      margin = Shared.effective_margin(@margin, nil, [], [0, 10], labels)

      assert margin.bottom > @margin.bottom
      assert margin.bottom >= 65
    end
  end

  describe "diagonal x-axis labels" do
    test "renders transform rotate and reduced font-size when labels > 3 chars" do
      bands = Plotto.Axis.categorical_scale(["2026-08-01", "2026-08-02"], 200)
      margin = Plotto.Theme.margin()
      labels = ["2026-08-01", "2026-08-02"]
      ticks = [0, 10, 20]

      elements = Shared.axis_elements(bands, margin, 200, 200, 0, 20, ticks, labels)

      x_text_elements =
        elements
        |> Enum.filter(&(&1.tag == "text" and hd(&1.children) in labels))

      for elem <- x_text_elements do
        assert elem.attrs["transform"] =~ "rotate(-45"
        assert elem.attrs["text-anchor"] == "end"
        assert elem.attrs["font-size"] == "10"
      end
    end

    test "renders horizontal x-axis labels when all labels are <= 3 chars" do
      bands = Plotto.Axis.categorical_scale(["Q1", "Q2", "Q3"], 200)
      margin = Plotto.Theme.margin()
      labels = ["Q1", "Q2", "Q3"]
      ticks = [0, 10, 20]

      elements = Shared.axis_elements(bands, margin, 200, 200, 0, 20, ticks, labels)

      x_text_elements =
        elements
        |> Enum.filter(&(&1.tag == "text" and hd(&1.children) in labels))

      for elem <- x_text_elements do
        refute Map.has_key?(elem.attrs, "transform")
        assert elem.attrs["text-anchor"] == "middle"
        assert elem.attrs["font-size"] == to_string(Plotto.Theme.font_size())
      end
    end
  end

  describe "horizontal legend and centered/middle positions" do
    @margin Plotto.Theme.margin()
    @row_height Plotto.Theme.legend_row_height()

    test "effective_margin adds only 1 row_height for horizontal top/bottom legends" do
      entries = [{"Series A", "#111"}, {"Series B", "#222"}, {"Series C", "#333"}]

      res_bottom = Shared.effective_margin(@margin, :bottom_center, entries, [], [], :horizontal)
      assert res_bottom.bottom == @margin.bottom + @row_height
      assert res_bottom.top == @margin.top

      res_top = Shared.effective_margin(@margin, :top_left, entries, [], [], :horizontal)
      assert res_top.top == @margin.top + @row_height
      assert res_top.bottom == @margin.bottom
    end

    test "effective_margin supports :right_middle and :left_middle" do
      entries = [{"Series A", "#111"}, {"Series B", "#222"}]

      res_right = Shared.effective_margin(@margin, :right_middle, entries, [], [], :vertical)
      assert res_right.right > @margin.right

      res_left = Shared.effective_margin(@margin, :left_middle, entries, [], [], :vertical)
      assert res_left.left > @margin.left
    end

    test "horizontal legend elements share the same Y center" do
      entries = [{"Alpha", "#111"}, {"Beta", "#222"}, {"Gamma", "#333"}]
      elements = Shared.legend_elements(entries, :bottom_center, @margin, 600, 400, :horizontal)

      swatches = Enum.filter(elements, &(&1.tag == "rect"))
      texts = Enum.filter(elements, &(&1.tag == "text"))

      assert length(swatches) == 3
      assert length(texts) == 3

      # All swatches share the same y
      [s1, s2, s3] = swatches
      assert s1.attrs["y"] == s2.attrs["y"]
      assert s2.attrs["y"] == s3.attrs["y"]

      # Distinct and increasing x coordinates
      x1 = elem(Float.parse(s1.attrs["x"]), 0)
      x2 = elem(Float.parse(s2.attrs["x"]), 0)
      x3 = elem(Float.parse(s3.attrs["x"]), 0)
      assert x1 < x2 and x2 < x3
    end

    test "horizontal legend respects left, center, and right alignments" do
      entries = [{"Alpha", "#111"}, {"Beta", "#222"}]

      els_left = Shared.legend_elements(entries, :bottom_left, @margin, 600, 400, :horizontal)
      els_center = Shared.legend_elements(entries, :bottom_center, @margin, 600, 400, :horizontal)
      els_right = Shared.legend_elements(entries, :bottom_right, @margin, 600, 400, :horizontal)

      x_left = elem(Float.parse(hd(els_left).attrs["x"]), 0)
      x_center = elem(Float.parse(hd(els_center).attrs["x"]), 0)
      x_right = elem(Float.parse(hd(els_right).attrs["x"]), 0)

      assert x_left < x_center
      assert x_center < x_right
    end

    test "horizontal legend truncates text with ellipsis when width is constrained" do
      entries = [
        {"Long Series Name Number One", "#111"},
        {"Long Series Name Number Two", "#222"}
      ]

      # Constrain width to 120px so long names must be truncated
      elements = Shared.legend_elements(entries, :bottom_center, @margin, 120, 300, :horizontal)
      texts = Enum.filter(elements, &(&1.tag == "text"))

      assert length(texts) == 2

      for t <- texts do
        [name] = t.children
        assert String.ends_with?(name, "…")
      end
    end

    test "vertical :right_middle centers rows vertically" do
      entries = [{"A", "#111"}, {"B", "#222"}]
      elements = Shared.legend_elements(entries, :right_middle, @margin, 600, 400, :vertical)
      swatches = Enum.filter(elements, &(&1.tag == "rect"))

      assert length(swatches) == 2
      y1 = elem(Float.parse(hd(swatches).attrs["y"]), 0)
      y2 = elem(Float.parse(List.last(swatches).attrs["y"]), 0)
      mid_y = (y1 + y2) / 2
      plot_center_y = @margin.top + (400 - @margin.top - @margin.bottom) / 2

      # The midpoint between the rows should be close to the plot center Y
      assert_in_delta mid_y, plot_center_y, 15.0
    end
  end
end
