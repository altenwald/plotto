defmodule Plotto.SVG.Renderer.LineChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.LineChart{data: data, opts: opts}) do
    default_stroke_width = Map.get(opts, :stroke_width) || Theme.stroke_width()
    line_styles = Map.get(opts, :line_styles, [])

    entries =
      data
      |> Enum.with_index()
      |> Enum.map(fn {series, index} ->
        color = Map.get(series, :color) || Theme.color(opts.colors, index)
        opt_style = Enum.at(line_styles, index)

        dotted? =
          Map.get(series, :dotted, false) ||
            Map.get(series, :style) == :dotted ||
            opt_style == :dotted

        dashed? =
          Map.get(series, :dashed, false) ||
            Map.get(series, :style) == :dashed ||
            opt_style == :dashed

        swatch_dash =
          cond do
            is_binary(Map.get(series, :stroke_dasharray)) -> Map.get(series, :stroke_dasharray)
            is_binary(opt_style) -> opt_style
            dotted? -> "2,3"
            dashed? -> "4,2"
            true -> nil
          end

        series_stroke_width =
          Map.get(series, :stroke_width) ||
            Map.get(series, :line_width) ||
            default_stroke_width

        {series.name, color,
         %{type: :line, stroke_dasharray: swatch_dash, stroke_width: series_stroke_width}}
      end)

    labels = ordered_labels(data)

    all_values =
      data
      |> Enum.flat_map(fn series -> Enum.map(series.data, & &1.value) end)

    raw_min = min(0, Enum.min(all_values))
    raw_max = max(0, Enum.max(all_values))
    ticks = Axis.ticks(raw_min, raw_max)
    min_value = List.first(ticks)
    max_value = List.last(ticks)

    margin =
      Shared.effective_margin(
        Theme.margin(),
        opts.legend,
        entries,
        ticks,
        labels,
        opts.legend_orientation
      )

    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    bands = Axis.categorical_scale(labels, plot_width)
    band_map = Map.new(bands, fn band -> {band.label, band} end)

    multi_series? = length(data) > 1

    {polylines, point_elements, label_elements} =
      data
      |> Enum.with_index()
      |> Enum.reduce({[], [], []}, fn {series, index}, {acc_lines, acc_pts, acc_lbls} ->
        color = Map.get(series, :color) || Theme.color(opts.colors, index)
        name = series.name
        opt_style = Enum.at(line_styles, index)

        dotted? =
          Map.get(series, :dotted, false) ||
            Map.get(series, :style) == :dotted ||
            opt_style == :dotted

        dashed? =
          Map.get(series, :dashed, false) ||
            Map.get(series, :style) == :dashed ||
            opt_style == :dashed

        dash_array =
          Map.get(series, :stroke_dasharray) ||
            cond do
              is_binary(opt_style) -> opt_style
              dotted? -> "2,4"
              dashed? -> "6,4"
              true -> nil
            end

        series_stroke_width =
          Map.get(series, :stroke_width) ||
            Map.get(series, :line_width) ||
            default_stroke_width

        points =
          series.data
          |> Enum.map(fn item ->
            band = Map.fetch!(band_map, item.label)
            x = margin.left + band.x
            y = margin.top + Axis.linear_scale(item.value, min_value, max_value, plot_height)
            {item, x, y}
          end)

        polyline = build_polyline(points, color, dash_array, series_stroke_width)
        pts = Enum.map(points, &build_point_circle(&1, color, opts.tooltip, name, multi_series?))
        lbls = build_point_labels(points, opts.label, name)

        {acc_lines ++ [polyline], acc_pts ++ pts, acc_lbls ++ lbls}
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
      Shared.axis_elements(
        bands,
        margin,
        plot_width,
        plot_height,
        min_value,
        max_value,
        ticks,
        labels
      ) ++
        polylines ++
        point_elements ++
        label_elements ++
        Shared.title_elements(opts.title, opts.width) ++
        legend

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp ordered_labels(data) do
    data
    |> Enum.map(fn series -> Enum.map(series.data, & &1.label) end)
    |> merge_label_lists()
  end

  defp merge_label_lists([]), do: []

  defp merge_label_lists([first | rest]) do
    Enum.reduce(rest, first, &merge_two_label_lists/2)
  end

  defp merge_two_label_lists(incoming, base) do
    Enum.reduce(incoming, base, fn label, acc ->
      if label in acc do
        acc
      else
        case find_insertion_index(incoming, label, acc) do
          nil -> acc ++ [label]
          idx -> List.insert_at(acc, idx, label)
        end
      end
    end)
  end

  defp find_insertion_index(incoming, label, acc) do
    idx_in_incoming = Enum.find_index(incoming, &(&1 == label))
    following = Enum.slice(incoming, (idx_in_incoming + 1)..-1//1)

    case Enum.find_value(following, &Enum.find_index(acc, fn x -> x == &1 end)) do
      nil -> nil
      acc_idx -> acc_idx
    end
  end

  defp build_point_labels(points, label_opt, series_name) do
    Enum.flat_map(points, fn {item, x, y} ->
      label_y = y - 7

      case Shared.label_element(
             item,
             x,
             label_y,
             label_opt,
             series_name,
             "plotto-label plotto-label-point"
           ) do
        nil -> []
        label_el -> [label_el]
      end
    end)
  end

  defp build_polyline(points, color, dash_array, stroke_width) do
    points_attr = Enum.map_join(points, " ", fn {_item, x, y} -> "#{fmt(x)},#{fmt(y)}" end)

    attrs =
      %{
        "points" => points_attr,
        "fill" => "none",
        "stroke" => color,
        "stroke-width" => fmt(stroke_width),
        "class" => "plotto-line"
      }
      |> maybe_put("stroke-dasharray", dash_array)

    Element.new("polyline", attrs)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp fmt(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp fmt(v), do: to_string(v)

  defp build_point_circle({item, x, y}, color, tooltip_opt, series_name, multi_series?) do
    default_title =
      if multi_series? and series_name do
        "#{series_name} - #{item.label}: #{Shared.format_val(item.value)}"
      else
        "#{item.label}: #{Shared.format_val(item.value)}"
      end

    base_attrs =
      %{
        "cx" => x,
        "cy" => y,
        "r" => 3,
        "fill" => color,
        "class" => "plotto-point"
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    {attrs, children} =
      Shared.apply_tooltip(base_attrs, default_title, tooltip_opt, item, series_name)

    Element.new("circle", attrs, children)
  end
end
