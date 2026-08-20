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
    bars = build_bars(data, bands, margin, plot_height, min_value, max_value, opts.colors, mode)

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
    all_values = data |> Enum.flat_map(& &1.data) |> Enum.map(& &1.value)
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

  defp build_bars(data, bands, margin, plot_height, min_value, max_value, colors, :grouped) do
    n_series = length(data)

    data
    |> Enum.with_index()
    |> Enum.flat_map(fn {series, series_index} ->
      color = Theme.color(colors, series_index)

      series.data
      |> Enum.zip(bands)
      |> Enum.map(
        &build_grouped_bar(
          &1,
          margin,
          plot_height,
          min_value,
          max_value,
          color,
          series_index,
          n_series
        )
      )
    end)
  end

  defp build_bars(data, bands, margin, plot_height, min_value, max_value, colors, :stacked) do
    n_categories = length(bands)

    for cat_index <- 0..(n_categories - 1) do
      band = Enum.at(bands, cat_index)

      {segments, _pos, _neg} =
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
              bottom_val,
              top_val
            )

          {[segment | acc_segments], next_pos, next_neg}
        end)

      Enum.reverse(segments)
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
         series_index,
         n_series
       ) do
    inner_width = band.band_width * 0.8
    inner_x = margin.left + band.band_x + band.band_width * 0.1
    sub_width = inner_width / n_series
    bar_x = inner_x + series_index * sub_width

    val_y = Axis.linear_scale(item.value, min_value, max_value, plot_height)
    zero_y = Axis.linear_scale(0, min_value, max_value, plot_height)
    top_y = margin.top + min(val_y, zero_y)
    bar_height = abs(val_y - zero_y)

    attrs =
      %{
        "x" => bar_x,
        "y" => top_y,
        "width" => sub_width,
        "height" => bar_height,
        "fill" => color
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    Element.new("rect", attrs)
  end

  defp build_stacked_segment(
         item,
         band,
         margin,
         plot_height,
         min_value,
         max_value,
         color,
         bottom_val,
         top_val
       ) do
    bar_width = band.band_width * 0.8
    bar_x = margin.left + band.band_x + band.band_width * 0.1

    y1 = Axis.linear_scale(bottom_val, min_value, max_value, plot_height)
    y2 = Axis.linear_scale(top_val, min_value, max_value, plot_height)
    top_y = margin.top + min(y1, y2)
    bar_height = abs(y1 - y2)

    attrs =
      %{
        "x" => bar_x,
        "y" => top_y,
        "width" => bar_width,
        "height" => bar_height,
        "fill" => color
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    Element.new("rect", attrs)
  end
end
