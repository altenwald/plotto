defmodule Plotto.SVG.Renderer.Shared do
  @moduledoc false

  alias Plotto.Font.{DejaVuSans, TrueType}
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
    axis_elements(bands, margin, plot_width, plot_height, 0, max_value)
  end

  def axis_elements(bands, margin, plot_width, plot_height, min_value, max_value) do
    ticks = Axis.ticks(min_value, max_value)
    labels = Enum.map(bands, & &1.label)
    axis_elements(bands, margin, plot_width, plot_height, min_value, max_value, ticks, labels)
  end

  def axis_elements(bands, margin, plot_width, plot_height, min_value, max_value, ticks, labels) do
    zero_y = margin.top + Axis.linear_scale(0, min_value, max_value, plot_height)

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
        "y1" => zero_y,
        "x2" => margin.left + plot_width,
        "y2" => zero_y,
        "stroke" => Theme.axis_color()
      })

    rotate_x? = rotate_x_labels?(labels)
    x_font_size = x_label_font_size(rotate_x?)
    x_labels = Enum.map(bands, &x_label(&1, margin, plot_height, rotate_x?, x_font_size))

    y_labels =
      Enum.map(
        ticks,
        &y_label(&1, margin, plot_height, min_value, max_value)
      )

    [y_axis_line, x_axis_line] ++ x_labels ++ y_labels
  end

  def rotate_x_labels?(labels) do
    Enum.any?(labels, fn label ->
      String.length(to_string(label)) > 3
    end)
  end

  def x_label_font_size(true), do: 10
  def x_label_font_size(false), do: Theme.font_size()

  def text_width(text, font_size) do
    font = DejaVuSans.font()
    scale = font_size / font.units_per_em

    text
    |> to_string()
    |> String.to_charlist()
    |> Enum.map(fn codepoint ->
      case TrueType.lookup_glyph(font, codepoint) do
        %{advance_width: w} -> w * scale
        nil -> font.missing_glyph_advance * scale
      end
    end)
    |> Enum.sum()
  end

  defp x_label(band, margin, plot_height, true, x_font_size) do
    x = margin.left + band.x
    y = margin.top + plot_height + 8

    Element.new(
      "text",
      %{
        "x" => x,
        "y" => y,
        "text-anchor" => "end",
        "transform" => "rotate(-45, #{x}, #{y})",
        "font-size" => x_font_size,
        "fill" => Theme.text_color()
      },
      [band.label]
    )
  end

  defp x_label(band, margin, plot_height, false, x_font_size) do
    x = margin.left + band.x
    y = margin.top + plot_height + x_font_size + 4

    Element.new(
      "text",
      %{
        "x" => x,
        "y" => y,
        "text-anchor" => "middle",
        "font-size" => x_font_size,
        "fill" => Theme.text_color()
      },
      [band.label]
    )
  end

  defp y_label(tick, margin, plot_height, min_value, max_value) do
    y = margin.top + Axis.linear_scale(tick, min_value, max_value, plot_height)

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

  def format_tick(tick) when is_integer(tick), do: Integer.to_string(tick)

  def format_tick(tick) when is_float(tick) do
    rounded = Float.round(tick, 6)

    if rounded == trunc(rounded) do
      Integer.to_string(trunc(rounded))
    else
      :erlang.float_to_binary(rounded, decimals: 2)
    end
  end

  def format_tick(tick), do: to_string(tick)

  def effective_margin(margin, legend, entries) do
    effective_margin(margin, legend, entries, [], [])
  end

  def effective_margin(margin, legend, entries, ticks, labels) do
    font_size = Theme.font_size()

    left_margin =
      case ticks do
        [] ->
          margin.left

        _ ->
          max_tick_w =
            ticks
            |> Enum.map(&format_tick/1)
            |> Enum.map(&text_width(&1, font_size))
            |> Enum.max(fn -> 0.0 end)

          max(margin.left, ceil(max_tick_w + 20))
      end

    rotate_x? = rotate_x_labels?(labels)
    x_font_size = x_label_font_size(rotate_x?)

    bottom_margin =
      if rotate_x? and labels != [] do
        max_label_w =
          labels
          |> Enum.map(&text_width(&1, x_font_size))
          |> Enum.max(fn -> 0.0 end)

        v_proj = (max_label_w + x_font_size) * 0.7071
        max(margin.bottom, ceil(v_proj + 20))
      else
        margin.bottom
      end

    margin = %{margin | left: left_margin, bottom: bottom_margin}

    case length(drawable_entries(legend, entries)) do
      0 ->
        margin

      n ->
        case legend do
          position when position in [:top_left, :top_right] ->
            Map.update!(margin, :top, &(&1 + Theme.legend_row_height() * n))

          position when position in [:bottom_left, :bottom_right] ->
            Map.update!(margin, :bottom, &(&1 + Theme.legend_row_height() * n))
        end
    end
  end

  def legend_elements(entries, legend, margin, width, height) do
    drawable = drawable_entries(legend, entries)
    n = length(drawable)

    drawable
    |> Enum.with_index()
    |> Enum.flat_map(fn {{name, color}, i} ->
      legend_row(name, color, legend, margin, width, height, i, n)
    end)
  end

  # Shared by effective_margin/3 and legend_elements/5 so they can never disagree
  # on "how many rows will actually draw" — filters out nil-named entries (the only
  # way a single-series chart with `name: nil` reaches this point, since
  # Plotto.Data.validate/1 requires non-nil names whenever there are 2+ series) and
  # returns [] outright for an invalid/nil `legend` position.
  defp drawable_entries(legend, entries) when legend in @legend_positions do
    Enum.filter(entries, fn {name, _color} -> not is_nil(name) end)
  end

  defp drawable_entries(_legend, _entries), do: []

  # Generalizes the single-row formula from the prior legend design (n = 1, i = 0
  # reduces to `anchor - row_height / 2`, matching it exactly): row `i` (0-based,
  # `i = 0` topmost) of `n` total rows.
  #
  # Top: anchored to `margin.top` (already enlarged by effective_margin/3) — the
  # title lives at a fixed absolute y independent of margin, so the band above the
  # (enlarged) margin.top is genuinely empty.
  #
  # Bottom: anchored to the absolute `height`, NOT `margin.bottom` — the x-axis tick
  # labels are positioned relative to margin.bottom (see `x_label/2` above), so they
  # shift down as margin.bottom grows; the actual empty space is the last
  # `row_height * n` pixels of the canvas. Anchoring to margin.bottom instead would
  # place the legend on the tick labels' baseline (a real bug caught in the prior
  # single-entry legend design).
  #
  # `y_center(i) = anchor - row_height * (n - i - 0.5)` is strictly increasing in
  # `i` regardless of anchor, so row 0 is topmost-within-the-band for both :top_*
  # and :bottom_* positions — no special-casing needed per anchor.
  defp legend_row(name, color, legend, margin, width, height, i, n) do
    swatch_size = Theme.legend_swatch_size()
    gap = Theme.legend_gap()
    row_height = Theme.legend_row_height()
    font_size = Theme.font_size()

    anchor =
      case legend do
        position when position in [:top_left, :top_right] -> margin.top
        position when position in [:bottom_left, :bottom_right] -> height
      end

    y_center = anchor - row_height * (n - i - 0.5)

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
end
