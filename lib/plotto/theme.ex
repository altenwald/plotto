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

  def default_colors, do: @default_colors
  def default_width, do: @default_width
  def default_height, do: @default_height
  def margin, do: @margin
  def axis_color, do: @axis_color
  def text_color, do: @text_color
  def font_size, do: @font_size
  def title_font_size, do: @title_font_size

  def color([], index), do: color(@default_colors, index)

  def color(colors, index) do
    Enum.at(colors, rem(index, length(colors)))
  end
end
