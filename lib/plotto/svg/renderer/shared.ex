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
        "height" => height,
        "class" => "plotto-chart"
      },
      children
    )
  end

  def format_val(v) when is_float(v) do
    if v == Float.round(v, 0) do
      to_string(trunc(v))
    else
      :erlang.float_to_binary(v, decimals: 2)
    end
  end

  def format_val(v), do: to_string(v)

  def apply_tooltip(attrs, default_title, tooltip_opt, item, series_name) do
    title_text =
      cond do
        is_function(tooltip_opt, 2) -> tooltip_opt.(item, series_name)
        is_function(tooltip_opt, 1) -> tooltip_opt.(item)
        true -> default_title
      end

    case tooltip_opt do
      opt when opt in [:native, :title] ->
        {attrs, [Element.new("title", %{}, [to_string(title_text)])]}

      opt when opt in [false, nil] ->
        {attrs, []}

      _data_default ->
        {Map.put(attrs, "data-title", to_string(title_text)), []}
    end
  end

  def label_text(label_opt, item, series_name) do
    cond do
      is_function(label_opt, 2) -> label_opt.(item, series_name)
      is_function(label_opt, 1) -> label_opt.(item)
      label_opt == :value -> format_val(item.value)
      label_opt in [true, :label, :top, :data] -> item.label
      is_binary(label_opt) -> label_opt
      true -> nil
    end
  end

  def label_element(item, x, y, label_opt, series_name, class_name) do
    case label_text(label_opt, item, series_name) do
      nil ->
        nil

      "" ->
        nil

      text ->
        Element.new(
          "text",
          %{
            "x" => x,
            "y" => y,
            "text-anchor" => "middle",
            "font-size" => Theme.label_font_size(),
            "fill" => Theme.text_color(),
            "class" => class_name
          },
          [to_string(text)]
        )
    end
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
          "fill" => Theme.text_color(),
          "class" => "plotto-title"
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
        "stroke" => Theme.axis_color(),
        "class" => "plotto-axis plotto-axis-y"
      })

    x_axis_line =
      Element.new("line", %{
        "x1" => margin.left,
        "y1" => zero_y,
        "x2" => margin.left + plot_width,
        "y2" => zero_y,
        "stroke" => Theme.axis_color(),
        "class" => "plotto-axis plotto-axis-x"
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
      String.length(to_string(label)) > 5
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
        "fill" => Theme.text_color(),
        "class" => "plotto-label plotto-label-x"
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
        "fill" => Theme.text_color(),
        "class" => "plotto-label plotto-label-x"
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
        "fill" => Theme.text_color(),
        "class" => "plotto-label plotto-label-y"
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

    case drawable_entries(legend, entries) do
      [] ->
        margin

      drawable ->
        n = length(drawable)

        case legend do
          position when position in [:top_left, :top_right] ->
            Map.update!(margin, :top, &(&1 + Theme.legend_row_height() * n))

          position when position in [:bottom_left, :bottom_right] ->
            Map.update!(margin, :bottom, &(&1 + Theme.legend_row_height() * n))

          position when position in [:right_top, :right_bottom] ->
            content_w = legend_content_width(drawable, font_size)
            Map.update!(margin, :right, &(&1 + content_w + 16))

          position when position in [:left_top, :left_bottom] ->
            content_w = legend_content_width(drawable, font_size)
            Map.update!(margin, :left, &(&1 + content_w + 16))

          _ ->
            margin
        end
    end
  end

  defp entry_swatch_width({_name, _color, %{type: :line}}), do: 18
  defp entry_swatch_width(_), do: Theme.legend_swatch_size()

  defp legend_content_width(drawable, font_size) do
    gap = Theme.legend_gap()

    max_swatch_w =
      drawable
      |> Enum.map(&entry_swatch_width/1)
      |> Enum.max(fn -> Theme.legend_swatch_size() end)

    max_text_w =
      drawable
      |> Enum.map(fn
        {name, _color} -> text_width(name, font_size)
        {name, _color, _meta} -> text_width(name, font_size)
      end)
      |> Enum.max(fn -> 0.0 end)

    ceil(max_swatch_w + gap + max_text_w)
  end

  def legend_elements(entries, legend, margin, width, height) do
    drawable = drawable_entries(legend, entries)
    n = length(drawable)

    drawable
    |> Enum.with_index()
    |> Enum.flat_map(fn {entry, i} ->
      legend_row(entry, legend, margin, width, height, i, n)
    end)
  end

  # Shared by effective_margin/3 and legend_elements/5 so they can never disagree
  # on "how many rows will actually draw" — filters out nil-named entries (the only
  # way a single-series chart with `name: nil` reaches this point, since
  # Plotto.Data.validate/1 requires non-nil names whenever there are 2+ series) and
  # returns [] outright for an invalid/nil `legend` position.
  defp drawable_entries(legend, entries) when legend in @legend_positions do
    Enum.filter(entries, fn
      {name, _color} -> not is_nil(name)
      {name, _color, _meta} -> not is_nil(name)
    end)
  end

  defp drawable_entries(_legend, _entries), do: []

  defp legend_row(entry, legend, margin, width, height, i, n) do
    {name, color, meta} =
      case entry do
        {name, color} -> {name, color, %{type: :rect}}
        {name, color, meta} -> {name, color, meta}
      end

    swatch_size = Theme.legend_swatch_size()

    swatch_width =
      Map.get(meta, :swatch_width) || if(meta[:type] == :line, do: 18, else: swatch_size)

    gap = Theme.legend_gap()
    row_height = Theme.legend_row_height()
    font_size = Theme.font_size()

    {y_center, swatch_x, text_x, text_anchor} =
      case legend do
        position when position in [:top_left, :top_right] ->
          anchor = margin.top
          y = anchor - row_height * (n - i - 0.5)

          case position do
            :top_left ->
              {y, margin.left, margin.left + swatch_width + gap, "start"}

            :top_right ->
              {y, width - margin.right - swatch_width, width - margin.right - swatch_width - gap,
               "end"}
          end

        position when position in [:bottom_left, :bottom_right] ->
          anchor = height
          y = anchor - row_height * (n - i - 0.5)

          case position do
            :bottom_left ->
              {y, margin.left, margin.left + swatch_width + gap, "start"}

            :bottom_right ->
              {y, width - margin.right - swatch_width, width - margin.right - swatch_width - gap,
               "end"}
          end

        position when position in [:right_top, :right_bottom] ->
          y =
            case position do
              :right_top ->
                margin.top + (i + 0.5) * row_height

              :right_bottom ->
                height - margin.bottom - (n - i - 0.5) * row_height
            end

          sx = width - margin.right + 12
          tx = sx + swatch_width + gap
          {y, sx, tx, "start"}

        position when position in [:left_top, :left_bottom] ->
          y =
            case position do
              :left_top ->
                margin.top + (i + 0.5) * row_height

              :left_bottom ->
                height - margin.bottom - (n - i - 0.5) * row_height
            end

          sx = 8
          tx = sx + swatch_width + gap
          {y, sx, tx, "start"}
      end

    swatch =
      case meta[:type] do
        :line ->
          line_stroke_width = Map.get(meta, :stroke_width, 2)

          line_attrs =
            %{
              "x1" => swatch_x,
              "y1" => y_center,
              "x2" => swatch_x + swatch_width,
              "y2" => y_center,
              "stroke" => color,
              "stroke-width" => to_string(line_stroke_width),
              "class" => "plotto-legend-swatch"
            }
            |> maybe_put("stroke-dasharray", meta[:stroke_dasharray])

          Element.new("line", line_attrs)

        _rect ->
          Element.new("rect", %{
            "x" => swatch_x,
            "y" => y_center - swatch_size / 2,
            "width" => swatch_size,
            "height" => swatch_size,
            "fill" => color,
            "class" => "plotto-legend-swatch"
          })
      end

    text =
      Element.new(
        "text",
        %{
          "x" => text_x,
          "y" => y_center + font_size / 2,
          "text-anchor" => text_anchor,
          "font-size" => font_size,
          "fill" => Theme.text_color(),
          "class" => "plotto-legend-text"
        },
        [name]
      )

    [swatch, text]
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
