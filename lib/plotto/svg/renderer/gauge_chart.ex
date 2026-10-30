defmodule Plotto.SVG.Renderer.GaugeChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.Theme

  @start_deg -210.0
  @end_deg 30.0
  @sweep_deg 240.0

  @default_threshold_colors [
    {0.60, "#2ECC71"},
    {0.85, "#F1C40F"},
    {1.00, "#E74C3C"}
  ]

  def render(%Plotto.GaugeChart{data: data, opts: opts}) do
    {min_value, max_value} = calculate_domain(data, opts)
    single? = length(data) == 1
    inline? = Map.get(opts, :inline, false) == true

    colored_items =
      data
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        color = resolve_color(item, index, single?, min_value, max_value, opts)
        {item, color, index}
      end)

    if inline? do
      render_inline(colored_items, min_value, max_value, opts)
    else
      render_full(colored_items, min_value, max_value, opts)
    end
  end

  defp render_inline(colored_items, min_value, max_value, opts) do
    margin = Theme.inline_margin()
    avail_w = max(8.0, (opts.width - margin.left - margin.right) / 1)
    avail_h = max(8.0, (opts.height - margin.top - margin.bottom) / 1)

    r_out = max(4.0, min(avail_w / 2.0, avail_h / 1.5))
    total_visual_h = 1.5 * r_out
    top_y = margin.top + max(0.0, (avail_h - total_visual_h) / 2.0)
    cx = margin.left + avail_w / 2.0
    cy = top_y + r_out

    rings = compute_rings(colored_items, r_out, true)

    arc_elements =
      Enum.flat_map(rings, fn {item, color, r_inner, r_outer} ->
        build_ring_elements(item, color, cx, cy, r_inner, r_outer, min_value, max_value, opts)
      end)

    Shared.svg_root(opts.width, opts.height, arc_elements, opts)
  end

  defp render_full(colored_items, min_value, max_value, opts) do
    entries =
      Enum.map(colored_items, fn {item, color, _idx} ->
        {item.label, color}
      end)

    base_margin = %{
      top: if(opts.title, do: 40, else: 20),
      right: 24,
      bottom: 24,
      left: 24
    }

    margin =
      Shared.effective_margin(
        base_margin,
        opts.legend,
        entries,
        [],
        [],
        opts.legend_orientation,
        opts
      )

    avail_w = max(40.0, (opts.width - margin.left - margin.right) / 1)
    avail_h = max(40.0, (opts.height - margin.top - margin.bottom) / 1)

    r_out = max(24.0, min((avail_w - 16.0) / 2.0, (avail_h - 28.0) / 1.5))
    total_visual_h = 1.5 * r_out + 20.0
    top_y = margin.top + max(0.0, (avail_h - total_visual_h) / 2.0)
    cx = margin.left + avail_w / 2.0
    cy = top_y + r_out

    rings = compute_rings(colored_items, r_out, false)

    arc_elements =
      Enum.flat_map(rings, fn {item, color, r_inner, r_outer} ->
        build_ring_elements(item, color, cx, cy, r_inner, r_outer, min_value, max_value, opts)
      end)

    {_first_item, _first_color, first_r_in, first_r_out} = List.first(rings)
    {_, _, innermost_r_in, _} = List.last(rings)

    minmax_elements =
      build_minmax_labels(cx, cy, first_r_in, first_r_out, min_value, max_value, opts)

    center_elements =
      build_center_labels(colored_items, cx, cy, r_out, innermost_r_in, opts)

    legend =
      Shared.legend_elements(
        entries,
        opts.legend,
        margin,
        opts.width,
        opts.height,
        opts.legend_orientation
      )

    children =
      arc_elements ++
        minmax_elements ++
        center_elements ++
        Shared.title_elements(opts.title, opts.width) ++
        legend

    Shared.svg_root(opts.width, opts.height, children, opts)
  end

  defp calculate_domain(data, opts) do
    values = Enum.map(data, & &1.value)
    data_min = Enum.min(values)
    data_max = Enum.max(values)

    min_val =
      case Map.get(opts, :y_min) do
        nil ->
          min(0, data_min)

        y_min when is_number(y_min) ->
          if Map.get(opts, :y_min_soft, false), do: min(data_min, y_min), else: y_min
      end

    max_threshold =
      case Map.get(opts, :thresholds) do
        list when is_list(list) and list != [] ->
          list |> Enum.map(&elem(&1, 0)) |> Enum.max()

        _ ->
          100
      end

    max_val =
      case Map.get(opts, :y_max) do
        nil ->
          max(max(100, max_threshold), data_max)

        y_max when is_number(y_max) ->
          if Map.get(opts, :y_max_soft, true), do: max(data_max, y_max), else: y_max
      end

    if min_val >= max_val do
      {min_val, min_val + 100}
    else
      {min_val, max_val}
    end
  end

  defp resolve_color(item, _index, true, min_value, max_value, opts) do
    Map.get(item, :color) ||
      threshold_color(item.value, min_value, max_value, Map.get(opts, :thresholds, [])) ||
      Theme.color(opts.colors, 0)
  end

  defp resolve_color(item, index, false, _min_value, _max_value, opts) do
    Map.get(item, :color) || Theme.color(opts.colors, index)
  end

  defp threshold_color(value, min_value, max_value, :default) do
    range = max_value - min_value

    thresholds =
      Enum.map(@default_threshold_colors, fn {ratio, color} ->
        {min_value + ratio * range, color}
      end)

    threshold_color(value, min_value, max_value, thresholds)
  end

  defp threshold_color(_value, _min_value, _max_value, []), do: nil
  defp threshold_color(_value, _min_value, _max_value, nil), do: nil
  defp threshold_color(_value, _min_value, _max_value, false), do: nil

  defp threshold_color(value, _min_value, _max_value, thresholds) when is_list(thresholds) do
    case Enum.find(thresholds, fn {limit, _color} -> value <= limit end) do
      {_limit, color} -> color
      nil -> thresholds |> List.last() |> elem(1)
    end
  end

  defp compute_rings([{item, color, _idx}], r_out, true) do
    ring_w = max(2.0, r_out * 0.30)
    [{item, color, r_out - ring_w, r_out}]
  end

  defp compute_rings([{item, color, _idx}], r_out, false) do
    ring_w = max(10.0, r_out * 0.22)
    [{item, color, r_out - ring_w, r_out}]
  end

  defp compute_rings(colored_items, r_out, true) do
    n = length(colored_items)
    total_band = r_out * 0.72
    gap = max(1.0, min(3.0, total_band * 0.15 / max(1, n - 1)))
    ring_w = max(1.5, (total_band - gap * (n - 1)) / n)

    Enum.map(colored_items, fn {item, color, idx} ->
      r_outer = r_out - idx * (ring_w + gap)
      r_inner = r_outer - ring_w
      {item, color, r_inner, r_outer}
    end)
  end

  defp compute_rings(colored_items, r_out, false) do
    n = length(colored_items)
    total_band = min(r_out * 0.52, max(20.0, r_out - 34.0))
    gap = max(3.0, min(8.0, total_band * 0.15 / max(1, n - 1)))
    ring_w = max(5.0, (total_band - gap * (n - 1)) / n)

    Enum.map(colored_items, fn {item, color, idx} ->
      r_outer = r_out - idx * (ring_w + gap)
      r_inner = r_outer - ring_w
      {item, color, r_inner, r_outer}
    end)
  end

  defp build_ring_elements(item, color, cx, cy, r_inner, r_outer, min_value, max_value, opts) do
    clamped = item.value |> max(min_value) |> min(max_value)
    ratio = (clamped - min_value) / (max_value - min_value)
    val_deg = @start_deg + ratio * @sweep_deg
    track_stroke_w = if Map.get(opts, :inline, false), do: "1", else: "1.5"

    default_title =
      if item.label do
        "#{item.label}: #{Shared.format_val(item.value, opts)}"
      else
        Shared.format_val(item.value, opts)
      end

    track_d = annular_sector_path(cx, cy, r_inner, r_outer, @start_deg, @end_deg)

    if val_deg > @start_deg + 0.01 do
      fill_d = annular_sector_path(cx, cy, r_inner, r_outer, @start_deg, val_deg)

      base_fill_attrs =
        %{
          "d" => fill_d,
          "fill" => color,
          "class" => "plotto-gauge-arc plotto-gauge-fill"
        }
        |> Map.merge(Map.get(item, :attrs, %{}))

      {fill_attrs, fill_children} =
        Shared.apply_tooltip(base_fill_attrs, default_title, opts.tooltip, item, item.label)

      fill_el = Element.new("path", fill_attrs, fill_children)

      track_el =
        Element.new("path", %{
          "d" => track_d,
          "fill" => "none",
          "stroke" => Theme.axis_color(),
          "stroke-width" => track_stroke_w,
          "class" => "plotto-gauge-track plotto-axis"
        })

      [fill_el, track_el]
    else
      base_track_attrs =
        %{
          "d" => track_d,
          "fill" => "none",
          "stroke" => Theme.axis_color(),
          "stroke-width" => track_stroke_w,
          "class" => "plotto-gauge-track plotto-axis"
        }
        |> Map.merge(Map.get(item, :attrs, %{}))

      {track_attrs, track_children} =
        Shared.apply_tooltip(base_track_attrs, default_title, opts.tooltip, item, item.label)

      [Element.new("path", track_attrs, track_children)]
    end
  end

  defp build_minmax_labels(cx, cy, r_in, r_out, min_value, max_value, opts) do
    font_size = Theme.font_size()
    r_mid = (r_in + r_out) / 2.0
    rad_start = @start_deg * :math.pi() / 180.0
    rad_end = @end_deg * :math.pi() / 180.0

    min_x = cx + r_mid * :math.cos(rad_start)
    max_x = cx + r_mid * :math.cos(rad_end)
    label_y = cy + r_out * :math.sin(rad_end) + font_size + 6.0

    min_el =
      Element.new(
        "text",
        %{
          "x" => min_x,
          "y" => label_y,
          "text-anchor" => "middle",
          "font-size" => font_size,
          "fill" => Theme.text_color(),
          "class" => "plotto-label plotto-gauge-minmax"
        },
        [Shared.format_tick(min_value, opts)]
      )

    max_el =
      Element.new(
        "text",
        %{
          "x" => max_x,
          "y" => label_y,
          "text-anchor" => "middle",
          "font-size" => font_size,
          "fill" => Theme.text_color(),
          "class" => "plotto-label plotto-gauge-minmax"
        },
        [Shared.format_tick(max_value, opts)]
      )

    [min_el, max_el]
  end

  defp build_center_labels([{item, _color, _idx}], cx, cy, r_out, r_in, opts) do
    val_text = Shared.format_val(item.value, opts)
    base_size = max(18, round(r_out * 0.24))
    raw_width = Shared.text_width(val_text, base_size)
    max_width = max(40.0, r_in * 1.45)

    val_font_size =
      if raw_width > max_width do
        max(14, floor(base_size * (max_width / raw_width)))
      else
        base_size
      end

    val_y = cy + val_font_size * 0.15

    val_el =
      Element.new(
        "text",
        %{
          "x" => cx,
          "y" => val_y,
          "text-anchor" => "middle",
          "font-size" => val_font_size,
          "fill" => Theme.text_color(),
          "class" => "plotto-label plotto-gauge-value"
        },
        [val_text]
      )

    if item.label do
      lbl_font_size = Theme.font_size()
      lbl_y = val_y + lbl_font_size + 8.0

      lbl_el =
        Element.new(
          "text",
          %{
            "x" => cx,
            "y" => lbl_y,
            "text-anchor" => "middle",
            "font-size" => lbl_font_size,
            "fill" => Theme.text_color(),
            "class" => "plotto-label plotto-gauge-label"
          },
          [item.label]
        )

      [val_el, lbl_el]
    else
      [val_el]
    end
  end

  defp build_center_labels(colored_items, cx, cy, _r_out, innermost_r_in, opts) do
    n = length(colored_items)
    row_font_size = max(10, min(14, round(innermost_r_in * 0.22)))
    line_h = row_font_size + 5.0
    start_y = cy - (n - 1) * line_h / 2.0 + row_font_size * 0.35

    Enum.map(colored_items, fn {item, _color, idx} ->
      text =
        if item.label do
          "#{item.label}: #{Shared.format_val(item.value, opts)}"
        else
          Shared.format_val(item.value, opts)
        end

      Element.new(
        "text",
        %{
          "x" => cx,
          "y" => start_y + idx * line_h,
          "text-anchor" => "middle",
          "font-size" => row_font_size,
          "fill" => Theme.text_color(),
          "class" => "plotto-label plotto-gauge-value"
        },
        [text]
      )
    end)
  end

  defp annular_sector_path(cx, cy, r_in, r_out, start_deg, end_deg) do
    rad1 = start_deg * :math.pi() / 180.0
    rad2 = end_deg * :math.pi() / 180.0

    x1 = cx + r_out * :math.cos(rad1)
    y1 = cy + r_out * :math.sin(rad1)
    x2 = cx + r_out * :math.cos(rad2)
    y2 = cy + r_out * :math.sin(rad2)
    x3 = cx + r_in * :math.cos(rad2)
    y3 = cy + r_in * :math.sin(rad2)
    x4 = cx + r_in * :math.cos(rad1)
    y4 = cy + r_in * :math.sin(rad1)

    large_arc = if end_deg - start_deg > 180.0, do: 1, else: 0

    "M #{fmt(x1)} #{fmt(y1)} " <>
      "A #{fmt(r_out)} #{fmt(r_out)} 0 #{large_arc} 1 #{fmt(x2)} #{fmt(y2)} " <>
      "L #{fmt(x3)} #{fmt(y3)} " <>
      "A #{fmt(r_in)} #{fmt(r_in)} 0 #{large_arc} 0 #{fmt(x4)} #{fmt(y4)} Z"
  end

  defp fmt(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp fmt(v), do: to_string(v)
end
