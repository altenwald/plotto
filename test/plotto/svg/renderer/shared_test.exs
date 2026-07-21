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

  describe "effective_margin/3" do
    test "returns the margin unchanged when legend is nil" do
      margin = Plotto.Theme.margin()
      assert Shared.effective_margin(margin, nil, "Sales") == margin
    end

    test "returns the margin unchanged when name is nil, even with a legend position" do
      margin = Plotto.Theme.margin()
      assert Shared.effective_margin(margin, :top_left, nil) == margin
    end

    test "adds legend_row_height to margin.top for :top_left/:top_right" do
      margin = Plotto.Theme.margin()
      row_height = Plotto.Theme.legend_row_height()

      for position <- [:top_left, :top_right] do
        result = Shared.effective_margin(margin, position, "Sales")
        assert result.top == margin.top + row_height
        assert result.bottom == margin.bottom
      end
    end

    test "adds legend_row_height to margin.bottom for :bottom_left/:bottom_right" do
      margin = Plotto.Theme.margin()
      row_height = Plotto.Theme.legend_row_height()

      for position <- [:bottom_left, :bottom_right] do
        result = Shared.effective_margin(margin, position, "Sales")
        assert result.bottom == margin.bottom + row_height
        assert result.top == margin.top
      end
    end
  end

  describe "legend_elements/6" do
    @margin Plotto.Theme.margin()

    test "returns [] when name is nil" do
      assert Shared.legend_elements(nil, :top_left, "#000000", @margin, 600, 400) == []
    end

    test "returns [] when legend is nil" do
      assert Shared.legend_elements("Sales", nil, "#000000", @margin, 600, 400) == []
    end

    test "returns [] for a legend atom outside the four valid positions (defensive — normally blocked upstream by Options.validate/1)" do
      assert Shared.legend_elements("Sales", :middle, "#000000", @margin, 600, 400) == []
    end

    test "returns a swatch <rect> and a <text> for a left position" do
      [swatch, text] = Shared.legend_elements("Sales", :top_left, "#4E79A7", @margin, 600, 400)

      assert swatch.tag == "rect"
      assert swatch.attrs["fill"] == "#4E79A7"
      assert text.tag == "text"
      assert text.attrs["text-anchor"] == "start"
      assert text.children == ["Sales"]
    end

    test "returns a swatch <rect> and a <text> for a right position" do
      [swatch, text] = Shared.legend_elements("Sales", :top_right, "#4E79A7", @margin, 600, 400)

      assert swatch.tag == "rect"
      assert text.attrs["text-anchor"] == "end"
    end

    # Note: use Float.parse/1, not String.to_float/1, to read numeric attrs back out —
    # Plotto.SVG.Element.new/3's format_value/1 only appends a decimal point to genuine
    # floats, so integer-valued attrs (e.g. margin.top itself) format as plain integer
    # strings like "40", which String.to_float/1 rejects with ArgumentError.
    # Plotto.PNG.Rasterizer already uses this same Float.parse/1 pattern for the same
    # reason (see its private num/1 helper).
    test "top positions place the swatch above the plot area (within the reserved band)" do
      margin = Shared.effective_margin(@margin, :top_left, "Sales")
      [swatch, _text] = Shared.legend_elements("Sales", :top_left, "#4E79A7", margin, 600, 400)

      swatch_y = elem(Float.parse(swatch.attrs["y"]), 0)
      assert swatch_y < margin.top
      assert swatch_y > margin.top - Plotto.Theme.legend_row_height()
    end

    test "bottom-position legend does not overlap the x-axis tick labels" do
      margin = Shared.effective_margin(@margin, :bottom_left, "Sales")
      plot_width = 600 - margin.left - margin.right
      plot_height = 400 - margin.top - margin.bottom
      bands = Plotto.Axis.categorical_scale(["Jan", "Feb"], plot_width)

      axis = Shared.axis_elements(bands, margin, plot_width, plot_height, 10)

      max_tick_label_y =
        axis
        |> Enum.filter(&(&1.tag == "text"))
        |> Enum.map(&elem(Float.parse(&1.attrs["y"]), 0))
        |> Enum.max()

      [swatch, _text] = Shared.legend_elements("Sales", :bottom_left, "#4E79A7", margin, 600, 400)
      swatch_y = elem(Float.parse(swatch.attrs["y"]), 0)

      # The legend must sit strictly below (larger y than) every axis tick label —
      # a prior version of this formula placed it on the exact same baseline as the
      # tick labels because it derived the band from the already-enlarged
      # margin.bottom instead of the canvas's absolute bottom edge.
      assert swatch_y > max_tick_label_y
    end
  end
end
