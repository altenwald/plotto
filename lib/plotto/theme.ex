defmodule Plotto.Theme do
  @moduledoc false

  @default_colors [
    "#4E79A7",
    "#F28E2B",
    "#E15759",
    "#76B7B2",
    "#59A14F"
  ]

  @default_width 600
  @default_height 400
  @margin %{top: 40, right: 24, bottom: 48, left: 56}
  @axis_color "#CCCCCC"
  @text_color "#333333"
  @font_size 12
  @title_font_size 18
  @legend_positions [:top_left, :top_right, :bottom_left, :bottom_right]
  @legend_swatch_size 10
  @legend_gap 6
  @legend_row_height 20
  @bullish_color "#26A69A"
  @bearish_color "#EF5350"

  def default_colors, do: @default_colors
  def default_width, do: @default_width
  def default_height, do: @default_height
  def margin, do: @margin
  def axis_color, do: @axis_color
  def text_color, do: @text_color
  def font_size, do: @font_size
  def title_font_size, do: @title_font_size
  def legend_positions, do: @legend_positions
  def legend_swatch_size, do: @legend_swatch_size
  def legend_gap, do: @legend_gap
  def legend_row_height, do: @legend_row_height
  def bullish_color, do: @bullish_color
  def bearish_color, do: @bearish_color

  def color([], index), do: color(@default_colors, index)

  def color(colors, index) do
    Enum.at(colors, rem(index, length(colors)))
  end
end
