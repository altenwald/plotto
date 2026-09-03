defmodule Plotto.PNG.Canvas do
  @moduledoc false

  defstruct [:width, :height, :pixels]

  # 0xFFFFFFFF = pack(255, 255, 255, 255) — inlined because a module attribute
  # cannot call a function defined in the same module (it isn't compiled yet
  # when attributes are evaluated).
  @white 0xFFFFFFFF

  def pack(r, g, b, a), do: r * 16_777_216 + g * 65_536 + b * 256 + a

  def unpack(color) do
    <<r::8, g::8, b::8, a::8>> = <<color::32>>
    {r, g, b, a}
  end

  def new(width, height) do
    %__MODULE__{
      width: width,
      height: height,
      pixels: :array.new(width * height, default: @white)
    }
  end

  def get_pixel(%__MODULE__{width: width} = canvas, x, y) do
    :array.get(y * width + x, canvas.pixels)
  end

  def put_pixel(%__MODULE__{width: width, height: height} = canvas, x, y, color)
      when x >= 0 and x < width and y >= 0 and y < height do
    %{canvas | pixels: :array.set(y * width + x, color, canvas.pixels)}
  end

  def put_pixel(canvas, _x, _y, _color), do: canvas

  def fill_rect(canvas, x, y, w, h, color) do
    x0 = round(x)
    y0 = round(y)
    x1 = round(x + w) - 1
    y1 = round(y + h) - 1

    Enum.reduce(y0..y1, canvas, fn py, canvas ->
      Enum.reduce(x0..x1, canvas, fn px, canvas -> put_pixel(canvas, px, py, color) end)
    end)
  end

  def fill_circle(canvas, cx, cy, r, color) do
    x0 = floor(cx - r)
    x1 = ceil(cx + r)
    y0 = floor(cy - r)
    y1 = ceil(cy + r)
    r_squared = r * r

    Enum.reduce(y0..y1, canvas, fn py, canvas ->
      Enum.reduce(x0..x1, canvas, fn px, canvas ->
        dx = px + 0.5 - cx
        dy = py + 0.5 - cy

        if dx * dx + dy * dy <= r_squared do
          put_pixel(canvas, px, py, color)
        else
          canvas
        end
      end)
    end)
  end

  def draw_line(canvas, x0, y0, x1, y1, color, width \\ 1, dash_pattern \\ nil)

  def draw_line(canvas, x0, y0, x1, y1, color, width, nil) do
    half = width / 2

    if abs(x1 - x0) >= abs(y1 - y0) do
      draw_line_x_major(canvas, x0, y0, x1, y1, color, half)
    else
      draw_line_y_major(canvas, x0, y0, x1, y1, color, half)
    end
  end

  def draw_line(canvas, x0, y0, x1, y1, color, width, []) do
    draw_line(canvas, x0, y0, x1, y1, color, width, nil)
  end

  def draw_line(canvas, x0, y0, x1, y1, color, width, dash_pattern) when is_list(dash_pattern) do
    draw_polyline(canvas, [{x0, y0}, {x1, y1}], color, width, dash_pattern)
  end

  defp draw_line_x_major(canvas, x0, y0, x1, y1, color, half) do
    {x0, y0, x1, y1} = if x0 <= x1, do: {x0, y0, x1, y1}, else: {x1, y1, x0, y0}
    dx = x1 - x0
    dy = y1 - y0

    Enum.reduce(round(x0)..round(x1), canvas, fn px, canvas ->
      t = if dx == 0, do: 0, else: (px - x0) / dx
      center_y = y0 + t * dy

      Enum.reduce(round(center_y - half)..round(center_y + half), canvas, fn py, canvas ->
        put_pixel(canvas, px, py, color)
      end)
    end)
  end

  defp draw_line_y_major(canvas, x0, y0, x1, y1, color, half) do
    {x0, y0, x1, y1} = if y0 <= y1, do: {x0, y0, x1, y1}, else: {x1, y1, x0, y0}
    dx = x1 - x0
    dy = y1 - y0

    Enum.reduce(round(y0)..round(y1), canvas, fn py, canvas ->
      t = if dy == 0, do: 0, else: (py - y0) / dy
      center_x = x0 + t * dx

      Enum.reduce(round(center_x - half)..round(center_x + half), canvas, fn px, canvas ->
        put_pixel(canvas, px, py, color)
      end)
    end)
  end

  def draw_polyline(canvas, points, color, width \\ 1, dash_pattern \\ nil)

  def draw_polyline(canvas, points, color, width, nil) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(canvas, fn [{x0, y0}, {x1, y1}], acc ->
      draw_line(acc, x0, y0, x1, y1, color, width, nil)
    end)
  end

  def draw_polyline(canvas, points, color, width, []) do
    draw_polyline(canvas, points, color, width, nil)
  end

  def draw_polyline(canvas, points, color, width, dash_pattern) when is_list(dash_pattern) do
    cycle_length = Enum.sum(dash_pattern)

    if cycle_length <= 0 do
      draw_polyline(canvas, points, color, width, nil)
    else
      segments = Enum.chunk_every(points, 2, 1, :discard)
      pattern_steps = build_pattern_steps(dash_pattern)

      {final_canvas, _final_offset} =
        Enum.reduce(segments, {canvas, 0.0}, fn [{x0, y0}, {x1, y1}], {acc, offset} ->
          dx = x1 - x0
          dy = y1 - y0
          seg_len = :math.sqrt(dx * dx + dy * dy)

          if seg_len == 0 do
            {acc, offset}
          else
            end_offset = offset + seg_len

            dash_ranges =
              calculate_dash_intervals(offset, end_offset, pattern_steps, cycle_length)

            acc_drawn =
              Enum.reduce(dash_ranges, acc, fn {d_start, d_end}, c ->
                t0 = (d_start - offset) / seg_len
                t1 = (d_end - offset) / seg_len
                sx0 = x0 + t0 * dx
                sy0 = y0 + t0 * dy
                sx1 = x0 + t1 * dx
                sy1 = y0 + t1 * dy
                draw_line(c, sx0, sy0, sx1, sy1, color, width, nil)
              end)

            new_offset = end_offset - Float.floor(end_offset / cycle_length) * cycle_length
            {acc_drawn, new_offset}
          end
        end)

      final_canvas
    end
  end

  defp calculate_dash_intervals(start_d, end_d, pattern_steps, cycle_length) do
    k0 = floor(start_d / cycle_length)
    k1 = floor(end_d / cycle_length)

    for k <- k0..k1,
        {offset, len, true} <- pattern_steps,
        dash_start = k * cycle_length + offset,
        dash_end = dash_start + len,
        i_start = max(start_d, dash_start),
        i_end = min(end_d, dash_end),
        i_start < i_end do
      {i_start, i_end}
    end
  end

  defp build_pattern_steps(pattern) do
    {steps, _total} =
      Enum.reduce(Enum.with_index(pattern), {[], 0.0}, fn {len, idx}, {acc, offset} ->
        is_dash? = rem(idx, 2) == 0
        {acc ++ [{offset, len, is_dash?}], offset + len}
      end)

    steps
  end

  def downsample(%__MODULE__{width: width, height: height} = canvas, factor) do
    new_width = div(width, factor)
    new_height = div(height, factor)

    pixels =
      for ny <- 0..(new_height - 1),
          nx <- 0..(new_width - 1),
          reduce: :array.new(new_width * new_height) do
        acc ->
          :array.set(
            ny * new_width + nx,
            average_block(canvas, nx * factor, ny * factor, factor),
            acc
          )
      end

    %__MODULE__{width: new_width, height: new_height, pixels: pixels}
  end

  defp average_block(canvas, x0, y0, factor) do
    {r, g, b, a} =
      for dy <- 0..(factor - 1), dx <- 0..(factor - 1), reduce: {0, 0, 0, 0} do
        {racc, gacc, bacc, aacc} ->
          {pr, pg, pb, pa} = unpack(get_pixel(canvas, x0 + dx, y0 + dy))
          {racc + pr, gacc + pg, bacc + pb, aacc + pa}
      end

    count = factor * factor
    pack(round(r / count), round(g / count), round(b / count), round(a / count))
  end

  def to_scanlines(%__MODULE__{width: width, height: height} = canvas) do
    for y <- 0..(height - 1) do
      for x <- 0..(width - 1), into: <<>> do
        <<get_pixel(canvas, x, y)::32>>
      end
    end
  end
end
