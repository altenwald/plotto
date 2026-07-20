defmodule Plotto.PNG.RasterizerTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.Element
  alias Plotto.PNG.{Canvas, Rasterizer}

  test "supersample_factor/0 is 4" do
    assert Rasterizer.supersample_factor() == 4
  end

  test "rasterize/3 creates a canvas at 4x the given width/height" do
    tree = Element.new("svg", %{}, [])
    canvas = Rasterizer.rasterize(tree, 10, 8)

    assert canvas.width == 40
    assert canvas.height == 32
  end

  test "a <rect> is scaled by 4x and filled with its color" do
    rect = Element.new("rect", %{x: 1, y: 1, width: 2, height: 2, fill: "#FF0000"})
    tree = Element.new("svg", %{}, [rect])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(255, 0, 0, 255)

    # rect spans x:[1,3) y:[1,3) in 1x units -> x:[4,12) y:[4,12) at 4x
    assert Canvas.get_pixel(canvas, 5, 5) == color
    assert Canvas.get_pixel(canvas, 0, 0) != color
  end

  test "a <circle> is scaled by 4x and filled with its color" do
    circle = Element.new("circle", %{cx: 5, cy: 5, r: 2, fill: "#00FF00"})
    tree = Element.new("svg", %{}, [circle])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(0, 255, 0, 255)

    assert Canvas.get_pixel(canvas, 20, 20) == color
  end

  test "a <line> is scaled by 4x and drawn with its stroke color" do
    line = Element.new("line", %{x1: 0, y1: 5, x2: 9, y2: 5, stroke: "#0000FF"})
    tree = Element.new("svg", %{}, [line])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(0, 0, 255, 255)

    assert Canvas.get_pixel(canvas, 20, 20) == color
  end

  test "a <polyline> is scaled by 4x and drawn with its stroke color" do
    polyline = Element.new("polyline", %{points: "0,5 9,5", fill: "none", stroke: "#0000FF"})
    tree = Element.new("svg", %{}, [polyline])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(0, 0, 255, 255)

    assert Canvas.get_pixel(canvas, 20, 20) == color
  end
end
