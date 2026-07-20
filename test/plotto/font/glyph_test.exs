defmodule Plotto.Font.GlyphTest do
  use ExUnit.Case, async: true

  alias Plotto.Font.{DejaVuSans, Glyph, TrueType}
  alias Plotto.PNG.Canvas

  test "draw/6 with an empty outline (e.g. space) leaves the canvas unchanged" do
    canvas = Canvas.new(10, 10)
    glyph = %{outline: [], advance_width: 500}

    result = Glyph.draw(canvas, glyph, 0, 0, 1.0, Canvas.pack(0, 0, 0, 255))

    assert result == canvas
  end

  test "draw/6 renders a real glyph ('A') producing a plausible bounding shape" do
    font = DejaVuSans.font()
    glyph = TrueType.lookup_glyph(font, ?A)

    # font_size 20, scaled to a small canvas: scale = font_size / units_per_em
    scale = 20 / font.units_per_em
    canvas = Canvas.new(30, 30)
    color = Canvas.pack(0, 0, 0, 255)

    result = Glyph.draw(canvas, glyph, 5, 25, scale, color)

    black_pixel_count =
      for x <- 0..29, y <- 0..29, Canvas.get_pixel(result, x, y) == color, reduce: 0 do
        acc -> acc + 1
      end

    # A 20px-tall "A" should paint a meaningful number of pixels, not zero and
    # not the entire canvas.
    assert black_pixel_count > 10
    assert black_pixel_count < 900
  end

  test "draw/6 renders a glyph with a hole (e.g. 'A') with the hole NOT filled" do
    font = DejaVuSans.font()
    glyph = TrueType.lookup_glyph(font, ?A)
    scale = 40 / font.units_per_em
    canvas = Canvas.new(60, 60)
    color = Canvas.pack(0, 0, 0, 255)

    result = Glyph.draw(canvas, glyph, 5, 55, scale, color)

    # The center of a large "A" (inside its triangular counter) should remain
    # unpainted thanks to non-zero winding across the outer+inner contours.
    assert Canvas.get_pixel(result, 30, 45) != color
  end
end
