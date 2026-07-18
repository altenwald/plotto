defmodule Plotto.SVG.Renderer.BarChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.BarChart{data: data, opts: opts}) do
    margin = Theme.margin()
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = Enum.map(data, & &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = data |> Enum.map(& &1.value) |> Enum.max()

    bars =
      data
      |> Enum.zip(bands)
      |> Enum.with_index()
      |> Enum.map(&build_bar(&1, margin, plot_height, max_value, opts.colors))

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        bars ++ Shared.title_elements(opts.title, opts.width)

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp build_bar({{item, band}, index}, margin, plot_height, max_value, colors) do
    bar_width = band.band_width * 0.8
    bar_x = margin.left + band.band_x + band.band_width * 0.1
    top_y = margin.top + Axis.linear_scale(item.value, max_value, plot_height)
    bar_height = plot_height - Axis.linear_scale(item.value, max_value, plot_height)

    attrs =
      %{
        "x" => bar_x,
        "y" => top_y,
        "width" => bar_width,
        "height" => bar_height,
        "fill" => Theme.color(colors, index)
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    Element.new("rect", attrs)
  end
end
