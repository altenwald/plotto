defmodule Plotto.Font.Glyph do
  @moduledoc false

  alias Plotto.PNG.Canvas

  def draw(canvas, %{outline: []}, _x, _y, _scale, _color), do: canvas

  def draw(canvas, %{outline: outline}, x, y, scale, color) do
    polygons =
      outline
      |> Enum.map(&flatten_contour/1)
      |> Enum.reject(&(&1 == []))
      |> Enum.map(fn contour ->
        Enum.map(contour, fn {gx, gy} -> {x + gx * scale, y - gy * scale} end)
      end)

    case bounding_box(polygons) do
      :empty ->
        canvas

      {min_x, max_x, min_y, max_y} ->
        Enum.reduce(round(min_y)..round(max_y), canvas, fn py, canvas ->
          Enum.reduce(round(min_x)..round(max_x), canvas, fn px, canvas ->
            if inside?(polygons, px + 0.5, py + 0.5) do
              Canvas.put_pixel(canvas, px, py, color)
            else
              canvas
            end
          end)
        end)
    end
  end

  defp bounding_box([]), do: :empty

  defp bounding_box(polygons) do
    points = List.flatten(polygons)
    xs = Enum.map(points, &elem(&1, 0))
    ys = Enum.map(points, &elem(&1, 1))
    {Enum.min(xs), Enum.max(xs), Enum.min(ys), Enum.max(ys)}
  end

  defp inside?(polygons, px, py) do
    Enum.reduce(polygons, 0, fn poly, acc -> acc + winding_number(poly, px, py) end) != 0
  end

  defp winding_number(poly, px, py) do
    edges = Enum.zip(poly, tl(poly) ++ [hd(poly)])

    Enum.reduce(edges, 0, fn {{x1, y1}, {x2, y2}}, acc ->
      cond do
        y1 <= py and y2 > py and is_left(x1, y1, x2, y2, px, py) > 0 -> acc + 1
        y1 > py and y2 <= py and is_left(x1, y1, x2, y2, px, py) < 0 -> acc - 1
        true -> acc
      end
    end)
  end

  defp is_left(x1, y1, x2, y2, px, py), do: (x2 - x1) * (py - y1) - (px - x1) * (y2 - y1)

  def flatten_contour(points) do
    points = ensure_starts_on_curve(points)
    closed = points ++ [List.first(points)]
    expand_implied_points(closed) |> build_segments()
  end

  defp ensure_starts_on_curve(points) do
    case Enum.find_index(points, & &1.on_curve) do
      0 ->
        points

      nil ->
        [p0 | _] = points
        last = List.last(points)
        [midpoint(last, p0) | points]

      idx ->
        {before, at_and_after} = Enum.split(points, idx)
        at_and_after ++ before
    end
  end

  defp midpoint(a, b), do: %{x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, on_curve: true}

  defp expand_implied_points([single]), do: [single]

  defp expand_implied_points([p1, p2 | rest]) do
    if not p1.on_curve and not p2.on_curve do
      [p1, midpoint(p1, p2) | expand_implied_points([p2 | rest])]
    else
      [p1 | expand_implied_points([p2 | rest])]
    end
  end

  defp build_segments([]), do: []
  defp build_segments([_last]), do: []

  defp build_segments([p1, p2]) when p1.on_curve and p2.on_curve do
    [{p1.x, p1.y}, {p2.x, p2.y}]
  end

  defp build_segments([p1, p2, p3 | rest]) when p1.on_curve and p2.on_curve do
    [{p1.x, p1.y} | build_segments([p2, p3 | rest])]
  end

  defp build_segments([p1, p2, p3 | rest]) when p1.on_curve and not p2.on_curve and p3.on_curve do
    flatten_quad_bezier(p1, p2, p3, 8) ++ build_segments([p3 | rest])
  end

  defp flatten_quad_bezier(p0, p1, p2, steps) do
    for i <- 0..(steps - 1) do
      t = i / steps
      mt = 1 - t
      x = mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x
      y = mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
      {x, y}
    end
  end
end
