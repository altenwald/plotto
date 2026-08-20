defmodule Plotto.SVG.Renderer.CandlestickChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.CandlestickChart{data: data, opts: opts}) do
    series = List.first(data)
    items = series.data

    entries =
      if series.name do
        [{series.name, opts.bullish_color}]
      else
        []
      end

    labels = Enum.map(items, & &1.label)
    all_lows = Enum.map(items, & &1.low)
    all_highs = Enum.map(items, & &1.high)
    raw_min = Enum.min(all_lows)
    raw_max = Enum.max(all_highs)
    ticks = Axis.ticks(raw_min, raw_max)
    min_value = List.first(ticks)
    max_value = List.last(ticks)

    margin = Shared.effective_margin(Theme.margin(), opts.legend, entries, ticks, labels)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    bands = Axis.categorical_scale(labels, plot_width)

    candle_elements =
      items
      |> Enum.zip(bands)
      |> Enum.flat_map(&build_candle(&1, margin, plot_height, min_value, max_value, opts))

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
        candle_elements ++ Shared.title_elements(opts.title, opts.width) ++ legend

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp build_candle({item, band}, margin, plot_height, min_value, max_value, opts) do
    center_x = margin.left + band.x
    is_bullish = item.close >= item.open
    color = if is_bullish, do: opts.bullish_color, else: opts.bearish_color

    high_y = margin.top + Axis.linear_scale(item.high, min_value, max_value, plot_height)
    low_y = margin.top + Axis.linear_scale(item.low, min_value, max_value, plot_height)
    open_y = margin.top + Axis.linear_scale(item.open, min_value, max_value, plot_height)
    close_y = margin.top + Axis.linear_scale(item.close, min_value, max_value, plot_height)

    wick_line =
      Element.new("line", %{
        "x1" => center_x,
        "y1" => high_y,
        "x2" => center_x,
        "y2" => low_y,
        "stroke" => color,
        "stroke-width" => 1.5
      })

    body_width = band.band_width * 0.7
    body_x = center_x - body_width / 2
    body_top_y = min(open_y, close_y)
    body_height = max(abs(close_y - open_y), 1.0)

    body_attrs =
      %{
        "x" => body_x,
        "y" => body_top_y,
        "width" => body_width,
        "height" => body_height,
        "fill" => color
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    body_rect = Element.new("rect", body_attrs)

    [wick_line, body_rect]
  end
end
