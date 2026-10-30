defmodule Plotto.SVG.Renderer.PieChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.Theme

  @start_deg -90.0

  def render(%Plotto.PieChart{data: data, opts: opts}) do
    inline? = Map.get(opts, :inline, false) == true
    labels = ordered_labels(data)
    color_map = build_color_map(data, labels, opts.colors)

    if inline? do
      render_inline(data, color_map, opts)
    else
      render_full(data, labels, color_map, opts)
    end
  end

  defp render_inline(data, color_map, opts) do
    margin = Theme.inline_margin()
    avail_w = max(8.0, (opts.width - margin.left - margin.right) / 1)
    avail_h = max(8.0, (opts.height - margin.top - margin.bottom) / 1)
    cx = margin.left + avail_w / 2.0
    cy = margin.top + avail_h / 2.0
    r_max = max(4.0, min(avail_w, avail_h) / 2.0)

    rings = compute_series_rings(data, r_max, opts.mode, true)
    multi_series? = length(data) > 1

    slice_elements =
      Enum.flat_map(rings, fn {series, r_in, r_out} ->
        {slices, _labels} =
          build_series_elements(series, cx, cy, r_in, r_out, color_map, multi_series?, true, opts)

        slices
      end)

    Shared.svg_root(opts.width, opts.height, slice_elements, opts)
  end

  defp render_full(data, labels, color_map, opts) do
    entries = Enum.map(labels, fn lbl -> {lbl, Map.fetch!(color_map, lbl)} end)

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
    cx = margin.left + avail_w / 2.0
    cy = margin.top + avail_h / 2.0
    r_max = max(24.0, min(avail_w, avail_h) / 2.0 - 8.0)

    rings = compute_series_rings(data, r_max, opts.mode, false)
    multi_series? = length(data) > 1

    {slice_elements, label_elements} =
      Enum.reduce(rings, {[], []}, fn {series, r_in, r_out}, {acc_slices, acc_labels} ->
        {slices, lbls} =
          build_series_elements(
            series,
            cx,
            cy,
            r_in,
            r_out,
            color_map,
            multi_series?,
            false,
            opts
          )

        {acc_slices ++ slices, acc_labels ++ lbls}
      end)

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
      slice_elements ++
        label_elements ++
        Shared.title_elements(opts.title, opts.width) ++
        legend

    Shared.svg_root(opts.width, opts.height, children, opts)
  end

  defp ordered_labels(data) do
    data
    |> Enum.flat_map(fn series -> Enum.map(series.data, & &1.label) end)
    |> Enum.uniq()
  end

  defp build_color_map(data, labels, colors) do
    explicit_colors =
      data
      |> Enum.flat_map(& &1.data)
      |> Enum.reduce(%{}, fn item, acc ->
        case Map.get(item, :color) do
          color when is_binary(color) -> Map.put_new(acc, item.label, color)
          _ -> acc
        end
      end)

    labels
    |> Enum.with_index()
    |> Map.new(fn {lbl, idx} ->
      color = Map.get(explicit_colors, lbl) || Theme.color(colors, idx)
      {lbl, color}
    end)
  end

  defp compute_series_rings([series], r_max, :donut, _inline?) do
    [{series, r_max * 0.52, r_max}]
  end

  defp compute_series_rings([series], r_max, _pie_mode, _inline?) do
    [{series, 0.0, r_max}]
  end

  defp compute_series_rings(data, r_max, mode, inline?) do
    n = length(data)
    hole_r = if mode == :donut, do: r_max * 0.30, else: 0.0
    gap = if inline?, do: 1.0, else: max(2.0, min(6.0, r_max * 0.03))
    total_band = r_max - hole_r
    ring_w = max(2.0, (total_band - gap * (n - 1)) / n)

    data
    |> Enum.with_index()
    |> Enum.map(fn {series, idx} ->
      r_outer = r_max - idx * (ring_w + gap)
      r_inner = max(0.0, r_outer - ring_w)
      {series, r_inner, r_outer}
    end)
  end

  defp build_series_elements(series, cx, cy, r_in, r_out, color_map, multi_series?, inline?, opts) do
    total = series.data |> Enum.map(& &1.value) |> Enum.sum()
    stroke_w = if inline?, do: "0.75", else: "1.5"

    {slices, labels, _final_deg} =
      Enum.reduce(series.data, {[], [], @start_deg}, fn item, {acc_s, acc_l, cur_deg} ->
        if item.value <= 0 do
          {acc_s, acc_l, cur_deg}
        else
          sweep = item.value / total * 360.0
          end_deg = cur_deg + sweep
          color = Map.get(item, :color) || Map.fetch!(color_map, item.label)
          d = slice_path(cx, cy, r_in, r_out, cur_deg, end_deg)

          pct_str = "#{round(item.value / total * 100)}%"

          default_title =
            if multi_series? and series.name do
              "#{series.name} - #{item.label}: #{Shared.format_val(item.value, opts)} (#{pct_str})"
            else
              "#{item.label}: #{Shared.format_val(item.value, opts)} (#{pct_str})"
            end

          base_attrs =
            %{
              "d" => d,
              "fill" => color,
              "stroke" => Theme.axis_color(),
              "stroke-width" => stroke_w,
              "class" => "plotto-pie-slice"
            }
            |> Map.merge(Map.get(item, :attrs, %{}))

          {attrs, children} =
            Shared.apply_tooltip(base_attrs, default_title, opts.tooltip, item, series.name)

          slice_el = Element.new("path", attrs, children)

          label_els =
            if inline? do
              []
            else
              build_slice_label(
                item,
                total,
                series.name,
                cx,
                cy,
                r_in,
                r_out,
                cur_deg,
                end_deg,
                opts
              )
            end

          {acc_s ++ [slice_el], acc_l ++ label_els, end_deg}
        end
      end)

    {slices, labels}
  end

  defp build_slice_label(item, total, series_name, cx, cy, r_in, r_out, start_deg, end_deg, opts) do
    text =
      case opts.label do
        mode when mode in [:percent, :percentage] ->
          "#{round(item.value / total * 100)}%"

        other ->
          Shared.label_text(other, item, series_name, opts)
      end

    case text do
      nil ->
        []

      "" ->
        []

      str ->
        mid_deg = (start_deg + end_deg) / 2.0
        mid_rad = mid_deg * :math.pi() / 180.0
        r_label = if r_in == 0.0, do: r_out * 0.65, else: (r_in + r_out) / 2.0
        lx = cx + r_label * :math.cos(mid_rad)
        ly = cy + r_label * :math.sin(mid_rad) + Theme.label_font_size() * 0.35

        [
          Element.new(
            "text",
            %{
              "x" => lx,
              "y" => ly,
              "text-anchor" => "middle",
              "font-size" => Theme.label_font_size(),
              "fill" => Theme.text_color(),
              "class" => "plotto-label plotto-label-pie"
            },
            [to_string(str)]
          )
        ]
    end
  end

  defp slice_path(cx, cy, r_in, r_out, start_deg, end_deg)
       when end_deg - start_deg >= 359.99 and r_in == 0.0 do
    mid_deg = start_deg + 180.0
    {x1, y1} = polar_point(cx, cy, r_out, start_deg)
    {xm, ym} = polar_point(cx, cy, r_out, mid_deg)

    "M #{fmt(x1)} #{fmt(y1)} " <>
      "A #{fmt(r_out)} #{fmt(r_out)} 0 1 1 #{fmt(xm)} #{fmt(ym)} " <>
      "A #{fmt(r_out)} #{fmt(r_out)} 0 1 1 #{fmt(x1)} #{fmt(y1)} Z"
  end

  defp slice_path(cx, cy, r_in, r_out, start_deg, end_deg)
       when end_deg - start_deg >= 359.99 do
    mid_deg = start_deg + 180.0
    {x1, y1} = polar_point(cx, cy, r_out, start_deg)
    {xm_out, ym_out} = polar_point(cx, cy, r_out, mid_deg)
    {x4, y4} = polar_point(cx, cy, r_in, start_deg)
    {xm_in, ym_in} = polar_point(cx, cy, r_in, mid_deg)

    "M #{fmt(x1)} #{fmt(y1)} " <>
      "A #{fmt(r_out)} #{fmt(r_out)} 0 1 1 #{fmt(xm_out)} #{fmt(ym_out)} " <>
      "A #{fmt(r_out)} #{fmt(r_out)} 0 1 1 #{fmt(x1)} #{fmt(y1)} " <>
      "L #{fmt(x4)} #{fmt(y4)} " <>
      "A #{fmt(r_in)} #{fmt(r_in)} 0 1 0 #{fmt(xm_in)} #{fmt(ym_in)} " <>
      "A #{fmt(r_in)} #{fmt(r_in)} 0 1 0 #{fmt(x4)} #{fmt(y4)} Z"
  end

  defp slice_path(cx, cy, r_in, r_out, start_deg, end_deg) when r_in == 0.0 do
    {x1, y1} = polar_point(cx, cy, r_out, start_deg)
    {x2, y2} = polar_point(cx, cy, r_out, end_deg)
    large_arc = if end_deg - start_deg > 180.0, do: 1, else: 0

    "M #{fmt(cx)} #{fmt(cy)} " <>
      "L #{fmt(x1)} #{fmt(y1)} " <>
      "A #{fmt(r_out)} #{fmt(r_out)} 0 #{large_arc} 1 #{fmt(x2)} #{fmt(y2)} Z"
  end

  defp slice_path(cx, cy, r_in, r_out, start_deg, end_deg) do
    {x1, y1} = polar_point(cx, cy, r_out, start_deg)
    {x2, y2} = polar_point(cx, cy, r_out, end_deg)
    {x3, y3} = polar_point(cx, cy, r_in, end_deg)
    {x4, y4} = polar_point(cx, cy, r_in, start_deg)
    large_arc = if end_deg - start_deg > 180.0, do: 1, else: 0

    "M #{fmt(x1)} #{fmt(y1)} " <>
      "A #{fmt(r_out)} #{fmt(r_out)} 0 #{large_arc} 1 #{fmt(x2)} #{fmt(y2)} " <>
      "L #{fmt(x3)} #{fmt(y3)} " <>
      "A #{fmt(r_in)} #{fmt(r_in)} 0 #{large_arc} 0 #{fmt(x4)} #{fmt(y4)} Z"
  end

  defp polar_point(cx, cy, r, deg) do
    rad = deg * :math.pi() / 180.0
    {cx + r * :math.cos(rad), cy + r * :math.sin(rad)}
  end

  defp fmt(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp fmt(v), do: to_string(v)
end
