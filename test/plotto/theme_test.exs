defmodule Plotto.ThemeTest do
  use ExUnit.Case, async: true

  alias Plotto.Theme

  test "default_colors/0 returns a non-empty list of hex colors" do
    colors = Theme.default_colors()
    assert is_list(colors)
    assert length(colors) > 0
    assert Enum.all?(colors, &String.starts_with?(&1, "#"))
  end

  test "default_width/0 and default_height/0 return positive integers" do
    assert Theme.default_width() > 0
    assert Theme.default_height() > 0
  end

  test "margin/0 returns a map with top/right/bottom/left keys" do
    margin = Theme.margin()
    assert %{top: _, right: _, bottom: _, left: _} = margin
  end

  test "color/2 cycles through the palette by index" do
    colors = ["#111111", "#222222"]
    assert Theme.color(colors, 0) == "#111111"
    assert Theme.color(colors, 1) == "#222222"
    assert Theme.color(colors, 2) == "#111111"
    assert Theme.color(colors, 3) == "#222222"
  end

  test "color/2 falls back to the default palette when given an empty list" do
    assert Theme.color([], 0) == List.first(Theme.default_colors())
  end

  test "legend_positions/0 returns the four valid corner atoms" do
    assert Theme.legend_positions() == [:top_left, :top_right, :bottom_left, :bottom_right]
  end

  test "legend_swatch_size/0, legend_gap/0, and legend_row_height/0 return positive integers" do
    assert Theme.legend_swatch_size() > 0
    assert Theme.legend_gap() > 0
    assert Theme.legend_row_height() > 0
  end

  test "bullish_color/0 and bearish_color/0 return hex colors" do
    assert String.starts_with?(Theme.bullish_color(), "#")
    assert String.starts_with?(Theme.bearish_color(), "#")
  end
end
