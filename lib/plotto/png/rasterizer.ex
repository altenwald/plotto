defmodule Plotto.PNG.Rasterizer do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.PNG.{Canvas, Color}
  alias Plotto.Font.{DejaVuSans, Glyph, TrueType}

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
    dash_pattern = parse_dasharray(attrs["stroke-dasharray"])

    Canvas.draw_line(canvas, x1, y1, x2, y2, color, width, dash_pattern)
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
    dash_pattern = parse_dasharray(attrs["stroke-dasharray"])

    Canvas.draw_polyline(canvas, points, color, width, dash_pattern)
  end

  defp draw_element(canvas, %Element{tag: "text", attrs: attrs, children: [text]}) do
    font = DejaVuSans.font()
    font_size = num(attrs["font-size"])
    scale = font_size / font.units_per_em * @supersample
    {:ok, color} = Color.parse(attrs["fill"])

    glyphs =
      text
      |> String.to_charlist()
      |> Enum.map(fn codepoint ->
        TrueType.lookup_glyph(font, codepoint) ||
          %{outline: [], advance_width: font.missing_glyph_advance}
      end)

    total_width = glyphs |> Enum.map(& &1.advance_width) |> Enum.sum() |> Kernel.*(scale)
    anchored_x = num(attrs["x"]) * @supersample

    start_x =
      case attrs["text-anchor"] do
        "middle" -> anchored_x - total_width / 2
        "end" -> anchored_x - total_width
        _ -> anchored_x
      end

    y = num(attrs["y"]) * @supersample
    rotation = parse_rotation(attrs["transform"], attrs["x"], attrs["y"])

    {canvas, _final_x} =
      Enum.reduce(glyphs, {canvas, start_x}, fn glyph, {canvas, x} ->
        canvas = Glyph.draw(canvas, glyph, x, y, scale, color, rotation)
        {canvas, x + glyph.advance_width * scale}
      end)

    canvas
  end

  defp parse_rotation(nil, _attr_x, _attr_y), do: nil

  defp parse_rotation(transform_str, attr_x, attr_y) do
    case Regex.run(
           ~r/rotate\(\s*([-\d.]+)(?:[,\s]+([-\d.]+)[,\s]+([-\d.]+))?\s*\)/,
           transform_str
         ) do
      [_, angle_str] ->
        angle_deg = num(angle_str)
        angle_rad = angle_deg * :math.pi() / 180.0
        pivot_x = num(attr_x) * @supersample
        pivot_y = num(attr_y) * @supersample
        {:math.cos(angle_rad), :math.sin(angle_rad), pivot_x, pivot_y}

      [_, angle_str, cx_str, cy_str] ->
        angle_deg = num(angle_str)
        angle_rad = angle_deg * :math.pi() / 180.0
        pivot_x = num(cx_str) * @supersample
        pivot_y = num(cy_str) * @supersample
        {:math.cos(angle_rad), :math.sin(angle_rad), pivot_x, pivot_y}

      _ ->
        nil
    end
  end

  defp num(str), do: elem(Float.parse(str), 0)

  defp parse_dasharray(nil), do: nil
  defp parse_dasharray(""), do: nil

  defp parse_dasharray(str) do
    numbers =
      str
      |> String.split([",", " "], trim: true)
      |> Enum.map(&(num(&1) * @supersample))

    case numbers do
      [] -> nil
      [single] -> [single, single]
      list when rem(length(list), 2) == 1 -> list ++ list
      list -> list
    end
  end
end
