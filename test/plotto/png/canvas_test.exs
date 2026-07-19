defmodule Plotto.PNG.CanvasTest do
  use ExUnit.Case, async: true

  alias Plotto.PNG.Canvas

  test "new/2 creates a canvas filled with opaque white" do
    canvas = Canvas.new(3, 2)
    assert canvas.width == 3
    assert canvas.height == 2
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
    assert Canvas.get_pixel(canvas, 2, 1) == Canvas.pack(255, 255, 255, 255)
  end

  test "pack/4 and unpack/1 round-trip" do
    color = Canvas.pack(10, 20, 30, 255)
    assert Canvas.unpack(color) == {10, 20, 30, 255}
  end

  test "put_pixel/4 sets a single pixel, leaving others unchanged" do
    color = Canvas.pack(255, 0, 0, 255)
    canvas = Canvas.new(2, 2) |> Canvas.put_pixel(1, 0, color)

    assert Canvas.get_pixel(canvas, 1, 0) == color
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
  end

  test "put_pixel/4 out of bounds is a no-op" do
    canvas = Canvas.new(2, 2)
    result = Canvas.put_pixel(canvas, 5, 5, Canvas.pack(0, 0, 0, 255))
    assert result == canvas
  end

  test "fill_rect/6 fills exactly the given area" do
    color = Canvas.pack(0, 255, 0, 255)
    canvas = Canvas.new(4, 4) |> Canvas.fill_rect(1, 1, 2, 2, color)

    assert Canvas.get_pixel(canvas, 1, 1) == color
    assert Canvas.get_pixel(canvas, 2, 2) == color
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
    assert Canvas.get_pixel(canvas, 3, 3) == Canvas.pack(255, 255, 255, 255)
  end

  test "fill_circle/5 fills pixels within radius and leaves the far corner untouched" do
    color = Canvas.pack(0, 0, 255, 255)
    canvas = Canvas.new(10, 10) |> Canvas.fill_circle(5, 5, 3, color)

    assert Canvas.get_pixel(canvas, 5, 5) == color
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
  end

  test "draw_line/7 draws a horizontal line with the given width" do
    color = Canvas.pack(0, 0, 0, 255)
    canvas = Canvas.new(10, 10) |> Canvas.draw_line(1, 5, 8, 5, color, 4)

    assert Canvas.get_pixel(canvas, 4, 5) == color
    assert Canvas.get_pixel(canvas, 4, 0) == Canvas.pack(255, 255, 255, 255)
  end

  test "downsample/2 averages each NxN block into one pixel" do
    canvas =
      Canvas.new(2, 2)
      |> Canvas.put_pixel(0, 0, Canvas.pack(0, 0, 0, 255))
      |> Canvas.put_pixel(1, 0, Canvas.pack(255, 255, 255, 255))
      |> Canvas.put_pixel(0, 1, Canvas.pack(0, 0, 0, 255))
      |> Canvas.put_pixel(1, 1, Canvas.pack(255, 255, 255, 255))

    result = Canvas.downsample(canvas, 2)

    assert result.width == 1
    assert result.height == 1
    assert Canvas.get_pixel(result, 0, 0) == Canvas.pack(128, 128, 128, 255)
  end

  test "to_scanlines/1 returns one binary per row, each width * 4 bytes" do
    canvas = Canvas.new(2, 1) |> Canvas.put_pixel(1, 0, Canvas.pack(1, 2, 3, 255))
    [scanline] = Canvas.to_scanlines(canvas)

    assert scanline == <<255, 255, 255, 255, 1, 2, 3, 255>>
  end
end
