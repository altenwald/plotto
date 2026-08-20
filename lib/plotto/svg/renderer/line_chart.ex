defmodule Plotto.SVG.Renderer.LineChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.LineChart{data: data, opts: opts}) do
    %{name: name, data: series_data} = List.first(data)
    color = Theme.color(opts.colors, 0)
    entries = [{name, color}]

    labels = Enum.map(series_data, & &1.label)
    values = Enum.map(series_data, & &1.value)
    raw_min = min(0, Enum.min(values))
    raw_max = max(0, Enum.max(values))
    ticks = Axis.ticks(raw_min, raw_max)
    min_value = List.first(ticks)
    max_value = List.last(ticks)

    margin = Shared.effective_margin(Theme.margin(), opts.legend, entries, ticks, labels)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    bands = Axis.categorical_scale(labels, plot_width)

    points =
      series_data
      |> Enum.zip(bands)
      |> Enum.map(fn {item, band} ->
        x = margin.left + band.x
        y = margin.top + Axis.linear_scale(item.value, min_value, max_value, plot_height)
        {item, x, y}
      end)

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
        [build_polyline(points, color)] ++
        Enum.map(points, &build_point_circle(&1, color)) ++
        Shared.title_elements(opts.title, opts.width) ++
        legend

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp build_polyline(points, color) do
    points_attr = Enum.map_join(points, " ", fn {_item, x, y} -> "#{fmt(x)},#{fmt(y)}" end)

    Element.new("polyline", %{
      "points" => points_attr,
      "fill" => "none",
      "stroke" => color
    })
  end

  defp fmt(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp fmt(v), do: to_string(v)

  defp build_point_circle({item, x, y}, color) do
    attrs =
      %{"cx" => x, "cy" => y, "r" => 3, "fill" => color}
      |> Map.merge(Map.get(item, :attrs, %{}))

    Element.new("circle", attrs)
  end
end
