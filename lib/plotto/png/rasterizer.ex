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

  defp draw_element(canvas, %Element{tag: "path", attrs: attrs}) do
    points = parse_path_d(attrs["d"])

    canvas =
      case attrs["fill"] do
        fill when is_binary(fill) and fill != "none" ->
          {:ok, fill_color} = Color.parse(fill)
          Canvas.fill_polygon(canvas, points, fill_color)

        _ ->
          canvas
      end

    case attrs["stroke"] do
      stroke when is_binary(stroke) and stroke != "none" and points != [] ->
        {:ok, stroke_color} = Color.parse(stroke)
        width = num(Map.get(attrs, "stroke-width", "1")) * @supersample
        dash_pattern = parse_dasharray(attrs["stroke-dasharray"])

        closed =
          if List.first(points) == List.last(points), do: points, else: points ++ [hd(points)]

        Canvas.draw_polyline(canvas, closed, stroke_color, width, dash_pattern)

      _ ->
        canvas
    end
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

  defp parse_path_d(nil), do: []
  defp parse_path_d(""), do: []

  defp parse_path_d(d_str) do
    tokens =
      ~r/[MLAZmlaz]|[-+]?\d*\.?\d+/
      |> Regex.scan(d_str)
      |> List.flatten()

    build_path_points(tokens, nil, nil, [])
  end

  defp build_path_points([], _cur, _start, acc), do: acc

  defp build_path_points([cmd, x_str, y_str | rest], _cur, _start, acc) when cmd in ["M", "m"] do
    pt = {num(x_str) * @supersample, num(y_str) * @supersample}
    build_path_points(rest, pt, pt, acc ++ [pt])
  end

  defp build_path_points([cmd, x_str, y_str | rest], _cur, start, acc) when cmd in ["L", "l"] do
    pt = {num(x_str) * @supersample, num(y_str) * @supersample}
    build_path_points(rest, pt, start, acc ++ [pt])
  end

  defp build_path_points(
         [cmd, rx_s, ry_s, _rot_s, laf_s, sf_s, x_s, y_s | rest],
         {x1, y1},
         start,
         acc
       )
       when cmd in ["A", "a"] do
    rx = num(rx_s) * @supersample
    ry = num(ry_s) * @supersample
    laf = round(num(laf_s))
    sf = round(num(sf_s))
    x2 = num(x_s) * @supersample
    y2 = num(y_s) * @supersample

    arc_pts = tessellate_arc(x1, y1, rx, ry, laf, sf, x2, y2)
    build_path_points(rest, {x2, y2}, start, acc ++ arc_pts)
  end

  defp build_path_points([cmd | rest], _cur, start, acc) when cmd in ["Z", "z"] do
    closed_acc =
      if start != nil and List.last(acc) != start do
        acc ++ [start]
      else
        acc
      end

    build_path_points(rest, start, start, closed_acc)
  end

  defp build_path_points([_unknown | rest], cur, start, acc) do
    build_path_points(rest, cur, start, acc)
  end

  defp tessellate_arc(x1, y1, rx, ry, _laf, _sf, x2, y2)
       when rx <= 0 or ry <= 0 or (x1 == x2 and y1 == y2) do
    [{x2, y2}]
  end

  defp tessellate_arc(x1, y1, rx, ry, laf, sf, x2, y2) do
    dx2 = (x1 - x2) / 2.0
    dy2 = (y1 - y2) / 2.0

    lambda = dx2 * dx2 / (rx * rx) + dy2 * dy2 / (ry * ry)

    {rx, ry} =
      if lambda > 1.0, do: {:math.sqrt(lambda) * rx, :math.sqrt(lambda) * ry}, else: {rx, ry}

    num_val = max(0.0, rx * rx * ry * ry - rx * rx * dy2 * dy2 - ry * ry * dx2 * dx2)
    den_val = rx * rx * dy2 * dy2 + ry * ry * dx2 * dx2
    factor = if den_val == 0.0, do: 0.0, else: :math.sqrt(num_val / den_val)
    sign = if laf == sf, do: -1.0, else: 1.0

    cx_prime = sign * factor * (rx * dy2 / ry)
    cy_prime = sign * factor * (-ry * dx2 / rx)
    cx = cx_prime + (x1 + x2) / 2.0
    cy = cy_prime + (y1 + y2) / 2.0

    ux = (dx2 - cx_prime) / rx
    uy = (dy2 - cy_prime) / ry
    vx = (-dx2 - cx_prime) / rx
    vy = (-dy2 - cy_prime) / ry

    theta1 = :math.atan2(uy, ux)
    raw_dtheta = :math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)

    dtheta =
      cond do
        sf == 0 and raw_dtheta > 0 -> raw_dtheta - 2.0 * :math.pi()
        sf == 1 and raw_dtheta < 0 -> raw_dtheta + 2.0 * :math.pi()
        true -> raw_dtheta
      end

    steps = max(16, round(abs(dtheta) / (:math.pi() / 36.0)))

    for i <- 1..steps do
      angle = theta1 + dtheta * (i / steps)
      {cx + rx * :math.cos(angle), cy + ry * :math.sin(angle)}
    end
  end
end
