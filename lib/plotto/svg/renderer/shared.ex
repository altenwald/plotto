defmodule Plotto.SVG.Renderer.Shared do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.{Axis, Theme}

  # Compile-time snapshot of Theme.legend_positions/0 — module attributes are inlined
  # as literals at compile time, so (unlike a direct Theme.legend_positions() call)
  # this can be referenced from a guard clause below.
  @legend_positions Theme.legend_positions()

  def svg_root(width, height, children) do
    Element.new(
      "svg",
      %{
        "xmlns" => "http://www.w3.org/2000/svg",
        "viewBox" => "0 0 #{width} #{height}",
        "width" => width,
        "height" => height
      },
      children
    )
  end

  def title_elements(nil, _width), do: []

  def title_elements(title, width) do
    [
      Element.new(
        "text",
        %{
          "x" => width / 2,
          "y" => Theme.title_font_size(),
          "text-anchor" => "middle",
          "font-size" => Theme.title_font_size(),
          "fill" => Theme.text_color()
        },
        [title]
      )
    ]
  end

  def axis_elements(bands, margin, plot_width, plot_height, max_value) do
    y_axis_line =
      Element.new("line", %{
        "x1" => margin.left,
        "y1" => margin.top,
        "x2" => margin.left,
        "y2" => margin.top + plot_height,
        "stroke" => Theme.axis_color()
      })

    x_axis_line =
      Element.new("line", %{
        "x1" => margin.left,
        "y1" => margin.top + plot_height,
        "x2" => margin.left + plot_width,
        "y2" => margin.top + plot_height,
        "stroke" => Theme.axis_color()
      })

    x_labels = Enum.map(bands, &x_label(&1, margin, plot_height))
    y_labels = Enum.map(Axis.ticks(max_value), &y_label(&1, margin, plot_height, max_value))

    [y_axis_line, x_axis_line] ++ x_labels ++ y_labels
  end

  defp x_label(band, margin, plot_height) do
    Element.new(
      "text",
      %{
        "x" => margin.left + band.x,
        "y" => margin.top + plot_height + Theme.font_size() + 4,
        "text-anchor" => "middle",
        "font-size" => Theme.font_size(),
        "fill" => Theme.text_color()
      },
      [band.label]
    )
  end

  defp y_label(tick, margin, plot_height, max_value) do
    y = margin.top + Axis.linear_scale(tick, max_value, plot_height)

    Element.new(
      "text",
      %{
        "x" => margin.left - 8,
        "y" => y + Theme.font_size() / 2,
        "text-anchor" => "end",
        "font-size" => Theme.font_size(),
        "fill" => Theme.text_color()
      },
      [format_tick(tick)]
    )
  end

  defp format_tick(tick) when is_integer(tick), do: Integer.to_string(tick)

  defp format_tick(tick) do
    rounded = Float.round(tick, 6)

    if rounded == trunc(rounded) do
      Integer.to_string(trunc(rounded))
    else
      :erlang.float_to_binary(rounded, decimals: 2)
    end
  end

  def effective_margin(margin, legend, name) do
    if draws_legend?(legend, name) do
      case legend do
        position when position in [:top_left, :top_right] ->
          Map.update!(margin, :top, &(&1 + Theme.legend_row_height()))

        position when position in [:bottom_left, :bottom_right] ->
          Map.update!(margin, :bottom, &(&1 + Theme.legend_row_height()))
      end
    else
      margin
    end
  end

  def legend_elements(nil, _legend, _color, _margin, _width, _height), do: []
  def legend_elements(_name, nil, _color, _margin, _width, _height), do: []

  def legend_elements(_name, legend, _color, _margin, _width, _height)
      when legend not in @legend_positions,
      do: []

  def legend_elements(name, legend, color, margin, width, height) do
    swatch_size = Theme.legend_swatch_size()
    gap = Theme.legend_gap()
    row_height = Theme.legend_row_height()
    font_size = Theme.font_size()

    # Top: the reserved band sits between the base margin.top (where the title lives,
    # at a fixed absolute y independent of margin) and the enlarged margin.top — so it's
    # anchored to `margin.top` (already enlarged by effective_margin/3).
    #
    # Bottom: the x-axis tick labels are positioned *relative to* margin.bottom (see
    # `x_label/2` above), so as margin.bottom grows the tick labels shift down with it —
    # the actual empty space freed up is the last `row_height` pixels of the canvas,
    # anchored to the absolute `height`, NOT to margin.bottom. Anchoring this to
    # margin.bottom instead (as an earlier version of this code did) would place the
    # legend on the exact same baseline as the tick labels for any dataset.
    #
    # By this point `legend` is guaranteed to be one of the four valid positions —
    # the guard clause above already returns [] for any other value, so neither
    # `case` below needs (or should have) a fallback clause.
    y_center =
      case legend do
        position when position in [:top_left, :top_right] -> margin.top - row_height / 2
        position when position in [:bottom_left, :bottom_right] -> height - row_height / 2
      end

    {swatch_x, text_x, text_anchor} =
      case legend do
        position when position in [:top_left, :bottom_left] ->
          {margin.left, margin.left + swatch_size + gap, "start"}

        position when position in [:top_right, :bottom_right] ->
          {width - margin.right - swatch_size, width - margin.right - swatch_size - gap, "end"}
      end

    swatch =
      Element.new("rect", %{
        "x" => swatch_x,
        "y" => y_center - swatch_size / 2,
        "width" => swatch_size,
        "height" => swatch_size,
        "fill" => color
      })

    text =
      Element.new(
        "text",
        %{
          "x" => text_x,
          "y" => y_center + font_size / 2,
          "text-anchor" => text_anchor,
          "font-size" => font_size,
          "fill" => Theme.text_color()
        },
        [name]
      )

    [swatch, text]
  end

  defp draws_legend?(legend, name) do
    legend in @legend_positions and not is_nil(name)
  end
end
