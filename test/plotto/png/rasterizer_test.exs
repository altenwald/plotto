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

  describe "text rendering" do
    test "a <text> with text-anchor=\"start\" paints pixels near its x,y" do
      text =
        Element.new(
          "text",
          %{x: 5, y: 20, "font-size": 12, "text-anchor": "start", fill: "#000000"},
          ["A"]
        )

      tree = Element.new("svg", %{}, [text])

      canvas = Rasterizer.rasterize(tree, 40, 40)
      color = Canvas.pack(0, 0, 0, 255)

      painted? =
        for x <- 0..159, y <- 0..159, reduce: false do
          acc -> acc or Canvas.get_pixel(canvas, x, y) == color
        end

      assert painted?
    end

    test "a <text> with an unsupported codepoint does not crash and still advances" do
      # U+1F600 (an emoji) is not in DejaVu Sans's cmap; this should render the
      # rest of the string without raising.
      text =
        Element.new("text", %{x: 5, y: 20, "font-size": 12, fill: "#000000"}, [
          <<0x1F600::utf8>> <> "A"
        ])

      tree = Element.new("svg", %{}, [text])

      assert %Plotto.PNG.Canvas{} = Rasterizer.rasterize(tree, 40, 40)
    end

    test "text-anchor=\"middle\" centers the text around x, differing from \"start\"" do
      start_text =
        Element.new(
          "text",
          %{x: 20, y: 20, "font-size": 12, "text-anchor": "start", fill: "#000000"},
          ["AAAA"]
        )

      middle_text =
        Element.new(
          "text",
          %{x: 20, y: 20, "font-size": 12, "text-anchor": "middle", fill: "#000000"},
          ["AAAA"]
        )

      start_canvas = Rasterizer.rasterize(Element.new("svg", %{}, [start_text]), 40, 40)
      middle_canvas = Rasterizer.rasterize(Element.new("svg", %{}, [middle_text]), 40, 40)

      refute start_canvas == middle_canvas
    end

    test "text with transform=\"rotate(angle, cx, cy)\" renders rotated pixels" do
      upright_text =
        Element.new(
          "text",
          %{x: 20, y: 20, "font-size": 12, "text-anchor": "start", fill: "#000000"},
          ["DATE"]
        )

      rotated_text =
        Element.new(
          "text",
          %{
            x: 20,
            y: 20,
            "font-size": 12,
            "text-anchor": "start",
            transform: "rotate(-45, 20, 20)",
            fill: "#000000"
          },
          ["DATE"]
        )

      upright_canvas = Rasterizer.rasterize(Element.new("svg", %{}, [upright_text]), 50, 50)
      rotated_canvas = Rasterizer.rasterize(Element.new("svg", %{}, [rotated_text]), 50, 50)

      refute upright_canvas == rotated_canvas

      color = Canvas.pack(0, 0, 0, 255)

      painted? =
        for x <- 0..199, y <- 0..199, reduce: false do
          acc -> acc or Canvas.get_pixel(rotated_canvas, x, y) == color
        end

      assert painted?
    end
  end
end
