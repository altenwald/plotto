defmodule Plotto.SVG.Renderer.BarChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.BarChart{data: data, opts: opts}) do
    mode = Map.get(opts, :mode, :grouped)

    entries =
      data
      |> Enum.with_index()
      |> Enum.map(fn {series, index} -> {series.name, Theme.color(opts.colors, index)} end)

    labels = data |> List.first() |> Map.fetch!(:data) |> Enum.map(& &1.label)
    {raw_min, raw_max} = calculate_domain(data, mode)
    ticks = Axis.ticks(raw_min, raw_max)
    min_value = List.first(ticks)
    max_value = List.last(ticks)

    margin = Shared.effective_margin(Theme.margin(), opts.legend, entries, ticks, labels)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    bands = Axis.categorical_scale(labels, plot_width)

    bars =
      build_bars(
        data,
        bands,
        margin,
        plot_height,
        min_value,
        max_value,
        opts.colors,
        mode,
        opts.tooltip,
        opts.label
      )

    legend = Shared.legend_elements(entries, opts.legend, margin, opts.width, opts.height)

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
        bars ++ Shared.title_elements(opts.title, opts.width) ++ legend

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp calculate_domain(data, :grouped) do
    all_values = data |> Enum.flat_map(fn series -> Enum.map(series.data, & &1.value) end)
    min_value = min(0, Enum.min(all_values))
    max_value = max(0, Enum.max(all_values))
    {min_value, max_value}
  end

  defp calculate_domain(data, :stacked) do
    n_categories = data |> List.first() |> Map.fetch!(:data) |> length()

    {min_neg, max_pos} =
      for cat_index <- 0..(n_categories - 1) do
        values = Enum.map(data, fn series -> Enum.at(series.data, cat_index).value end)
        pos_sum = values |> Enum.filter(&(&1 > 0)) |> Enum.sum()
        neg_sum = values |> Enum.filter(&(&1 < 0)) |> Enum.sum()
        {neg_sum, pos_sum}
      end
      |> Enum.reduce({0, 0}, fn {neg_sum, pos_sum}, {min_neg, max_pos} ->
        {min(min_neg, neg_sum), max(max_pos, pos_sum)}
      end)

    {min(0, min_neg), max(0, max_pos)}
  end

  defp build_bars(
         data,
         bands,
         margin,
         plot_height,
         min_value,
         max_value,
         colors,
         :grouped,
         tooltip_opt,
         label_opt
       ) do
    n_series = length(data)

    data
    |> Enum.with_index()
    |> Enum.flat_map(fn {series, series_index} ->
      color = Theme.color(colors, series_index)

      series.data
      |> Enum.zip(bands)
      |> Enum.flat_map(
        &build_grouped_bar(
          &1,
          margin,
          plot_height,
          min_value,
          max_value,
          color,
          series.name,
          series_index,
          n_series,
          tooltip_opt,
          label_opt
        )
      )
    end)
  end

  defp build_bars(
         data,
         bands,
         margin,
         plot_height,
         min_value,
         max_value,
         colors,
         :stacked,
         tooltip_opt,
         label_opt
       ) do
    n_categories = length(bands)

    for cat_index <- 0..(n_categories - 1) do
      band = Enum.at(bands, cat_index)

      {segments, pos_total, neg_total} =
        data
        |> Enum.with_index()
        |> Enum.reduce({[], 0, 0}, fn {series, series_index},
                                      {acc_segments, pos_base, neg_base} ->
          item = Enum.at(series.data, cat_index)
          color = Theme.color(colors, series_index)

          {bottom_val, top_val, next_pos, next_neg} =
            if item.value >= 0 do
              {pos_base, pos_base + item.value, pos_base + item.value, neg_base}
            else
              {neg_base, neg_base + item.value, pos_base, neg_base + item.value}
            end

          segment =
            build_stacked_segment(
              item,
              band,
              margin,
              plot_height,
              min_value,
              max_value,
              color,
              series.name,
              bottom_val,
              top_val,
              tooltip_opt
            )

          {[segment | acc_segments], next_pos, next_neg}
        end)

      ordered_segments = Enum.reverse(segments)

      category_label = band.label
      total_val = if pos_total != 0, do: pos_total, else: neg_total
      summary_item = %{label: category_label, value: total_val}
      bar_width = band.band_width * 0.8
      bar_x = margin.left + band.band_x + band.band_width * 0.1
      label_x = bar_x + bar_width / 2
      pos_y = Axis.linear_scale(pos_total, min_value, max_value, plot_height)
      zero_y = Axis.linear_scale(0, min_value, max_value, plot_height)
      top_y = margin.top + min(pos_y, zero_y)
      label_y = top_y - 4

      case Shared.label_element(
             summary_item,
             label_x,
             label_y,
             label_opt,
             nil,
             "plotto-label plotto-label-bar"
           ) do
        nil -> ordered_segments
        label_el -> ordered_segments ++ [label_el]
      end
    end
    |> List.flatten()
  end

  defp build_grouped_bar(
         {item, band},
         margin,
         plot_height,
         min_value,
         max_value,
         color,
         series_name,
         series_index,
         n_series,
         tooltip_opt,
         label_opt
       ) do
    inner_width = band.band_width * 0.8
    inner_x = margin.left + band.band_x + band.band_width * 0.1
    sub_width = inner_width / n_series
    bar_x = inner_x + series_index * sub_width

    val_y = Axis.linear_scale(item.value, min_value, max_value, plot_height)
    zero_y = Axis.linear_scale(0, min_value, max_value, plot_height)
    top_y = margin.top + min(val_y, zero_y)
    bar_height = abs(val_y - zero_y)

    default_title =
      if series_name do
        "#{series_name}: #{Shared.format_val(item.value)} (#{item.label})"
      else
        "#{item.label}: #{Shared.format_val(item.value)}"
      end

    base_attrs =
      %{
        "x" => bar_x,
        "y" => top_y,
        "width" => sub_width,
        "height" => bar_height,
        "fill" => color,
        "class" => "plotto-bar"
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    {attrs, children} =
      Shared.apply_tooltip(base_attrs, default_title, tooltip_opt, item, series_name)

    rect = Element.new("rect", attrs, children)

    label_x = bar_x + sub_width / 2
    label_y = top_y - 4

    case Shared.label_element(
           item,
           label_x,
           label_y,
           label_opt,
           series_name,
           "plotto-label plotto-label-bar"
         ) do
      nil -> [rect]
      label_el -> [rect, label_el]
    end
  end

  defp build_stacked_segment(
         item,
         band,
         margin,
         plot_height,
         min_value,
         max_value,
         color,
         series_name,
         bottom_val,
         top_val,
         tooltip_opt
       ) do
    bar_width = band.band_width * 0.8
    bar_x = margin.left + band.band_x + band.band_width * 0.1

    y1 = Axis.linear_scale(bottom_val, min_value, max_value, plot_height)
    y2 = Axis.linear_scale(top_val, min_value, max_value, plot_height)
    top_y = margin.top + min(y1, y2)
    bar_height = abs(y1 - y2)

    default_title =
      if series_name do
        "#{series_name}: #{Shared.format_val(item.value)} (#{item.label})"
      else
        "#{item.label}: #{Shared.format_val(item.value)}"
      end

    base_attrs =
      %{
        "x" => bar_x,
        "y" => top_y,
        "width" => bar_width,
        "height" => bar_height,
        "fill" => color,
        "class" => "plotto-bar"
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    {attrs, children} =
      Shared.apply_tooltip(base_attrs, default_title, tooltip_opt, item, series_name)

    Element.new("rect", attrs, children)
  end
end
