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
end
