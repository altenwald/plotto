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
  end
end
