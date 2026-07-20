defmodule Plotto.PNG.Rasterizer do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.PNG.{Canvas, Color}

  @supersample 4

  def supersample_factor, do: @supersample

  def rasterize(%Element{} = root, width, height) do
    canvas = Canvas.new(width * @supersample, height * @supersample)
    draw_element(canvas, root)
  end

  defp draw_element(canvas, %Element{tag: "svg", children: children}) do
    Enum.reduce(children, canvas, fn child, canvas -> draw_element(canvas, child) end)
  end

  defp draw_element(canvas, %Element{tag: "g", children: children}) do
    Enum.reduce(children, canvas, fn child, canvas -> draw_element(canvas, child) end)
  end

  defp draw_element(canvas, %Element{tag: "rect", attrs: attrs}) do
    x = num(attrs["x"]) * @supersample
    y = num(attrs["y"]) * @supersample
    w = num(attrs["width"]) * @supersample
    h = num(attrs["height"]) * @supersample
    {:ok, color} = Color.parse(attrs["fill"])

    Canvas.fill_rect(canvas, x, y, w, h, color)
  end

  defp draw_element(canvas, %Element{tag: "circle", attrs: attrs}) do
    cx = num(attrs["cx"]) * @supersample
    cy = num(attrs["cy"]) * @supersample
    r = num(attrs["r"]) * @supersample
    {:ok, color} = Color.parse(attrs["fill"])

    Canvas.fill_circle(canvas, cx, cy, r, color)
  end

  defp draw_element(canvas, %Element{tag: "line", attrs: attrs}) do
    x1 = num(attrs["x1"]) * @supersample
    y1 = num(attrs["y1"]) * @supersample
    x2 = num(attrs["x2"]) * @supersample
    y2 = num(attrs["y2"]) * @supersample
    {:ok, color} = Color.parse(attrs["stroke"])
    width = num(Map.get(attrs, "stroke-width", "1")) * @supersample

    Canvas.draw_line(canvas, x1, y1, x2, y2, color, width)
  end

  defp draw_element(canvas, %Element{tag: "polyline", attrs: attrs}) do
    points =
      attrs["points"]
      |> String.split(" ")
      |> Enum.map(fn pair ->
        [x, y] = String.split(pair, ",")
        {num(x) * @supersample, num(y) * @supersample}
      end)

    {:ok, color} = Color.parse(attrs["stroke"])
    width = num(Map.get(attrs, "stroke-width", "1")) * @supersample

    Canvas.draw_polyline(canvas, points, color, width)
  end

  defp draw_element(canvas, %Element{tag: "text"}), do: canvas

  defp num(str), do: elem(Float.parse(str), 0)
end
