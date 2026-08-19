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

    margin = Shared.effective_margin(Theme.margin(), opts.legend, entries)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = data |> List.first() |> Map.fetch!(:data) |> Enum.map(& &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = calculate_max_value(data, mode)
    bars = build_bars(data, bands, margin, plot_height, max_value, opts.colors, mode)

    legend = Shared.legend_elements(entries, opts.legend, margin, opts.width, opts.height)

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        bars ++ Shared.title_elements(opts.title, opts.width) ++ legend

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp calculate_max_value(data, :grouped) do
    data |> Enum.flat_map(& &1.data) |> Enum.map(& &1.value) |> Enum.max()
  end

  defp calculate_max_value(data, :stacked) do
    category_totals =
      data
      |> Enum.map(fn series -> Enum.map(series.data, & &1.value) end)
      |> List.zip()
      |> Enum.map(fn tuple -> Tuple.to_list(tuple) |> Enum.sum() end)

    if category_totals == [], do: 0, else: Enum.max(category_totals)
  end

  defp build_bars(data, bands, margin, plot_height, max_value, colors, :grouped) do
    n_series = length(data)

    data
    |> Enum.with_index()
    |> Enum.flat_map(fn {series, series_index} ->
      color = Theme.color(colors, series_index)

      series.data
      |> Enum.zip(bands)
      |> Enum.map(&build_grouped_bar(&1, margin, plot_height, max_value, color, series_index, n_series))
    end)
  end

  defp build_bars(data, bands, margin, plot_height, max_value, colors, :stacked) do
    n_categories = length(bands)

    for cat_index <- 0..(n_categories - 1) do
      band = Enum.at(bands, cat_index)

      {segments, _cumulative} =
        data
        |> Enum.with_index()
        |> Enum.reduce({[], 0}, fn {series, series_index}, {acc_segments, bottom_val} ->
          item = Enum.at(series.data, cat_index)
          color = Theme.color(colors, series_index)
          top_val = bottom_val + item.value

          segment =
            build_stacked_segment(
              item,
              band,
              margin,
              plot_height,
              max_value,
              color,
              bottom_val,
              top_val
            )

          {[segment | acc_segments], top_val}
        end)

      Enum.reverse(segments)
    end
    |> List.flatten()
  end

  defp build_grouped_bar(
         {item, band},
         margin,
         plot_height,
         max_value,
         color,
         series_index,
         n_series
       ) do
    inner_width = band.band_width * 0.8
    inner_x = margin.left + band.band_x + band.band_width * 0.1
    sub_width = inner_width / n_series
    bar_x = inner_x + series_index * sub_width

    top_y = margin.top + Axis.linear_scale(item.value, max_value, plot_height)
    bar_height = plot_height - Axis.linear_scale(item.value, max_value, plot_height)

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
         max_value,
         color,
         bottom_val,
         top_val
       ) do
    bar_width = band.band_width * 0.8
    bar_x = margin.left + band.band_x + band.band_width * 0.1

    top_y = margin.top + Axis.linear_scale(top_val, max_value, plot_height)
    bottom_y = margin.top + Axis.linear_scale(bottom_val, max_value, plot_height)
    bar_height = bottom_y - top_y

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
