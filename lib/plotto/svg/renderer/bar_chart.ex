defmodule Plotto.SVG.Renderer.BarChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.BarChart{data: data, opts: opts}) do
    entries =
      data
      |> Enum.with_index()
      |> Enum.map(fn {series, index} -> {series.name, Theme.color(opts.colors, index)} end)

    margin = Shared.effective_margin(Theme.margin(), opts.legend, entries)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = data |> List.first() |> Map.fetch!(:data) |> Enum.map(& &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = data |> Enum.flat_map(& &1.data) |> Enum.map(& &1.value) |> Enum.max()
    n_series = length(data)

    bars =
      data
      |> Enum.with_index()
      |> Enum.flat_map(fn {series, series_index} ->
        color = Theme.color(opts.colors, series_index)

        series.data
        |> Enum.zip(bands)
        |> Enum.map(&build_bar(&1, margin, plot_height, max_value, color, series_index, n_series))
      end)

    legend = Shared.legend_elements(entries, opts.legend, margin, opts.width, opts.height)

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        bars ++ Shared.title_elements(opts.title, opts.width) ++ legend

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp build_bar({item, band}, margin, plot_height, max_value, color, series_index, n_series) do
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
end
