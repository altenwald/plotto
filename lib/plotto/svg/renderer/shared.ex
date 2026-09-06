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

  def format_val(v, opts \\ %{})

  def format_val(v, opts) when is_float(v) do
    base =
      if v == Float.round(v, 0) do
        to_string(trunc(v))
      else
        :erlang.float_to_binary(v, decimals: 2)
      end

    decorate_val(base, opts)
  end

  def format_val(v, opts), do: decorate_val(to_string(v), opts)

  def decorate_val(base, opts) do
    prefix = get_opt(opts, :value_prefix) || ""
    suffix = get_opt(opts, :value_suffix) || ""

    case {prefix, suffix} do
      {"", ""} ->
        base

      {p, s} ->
        if String.starts_with?(base, "-") do
          "-" <> p <> String.slice(base, 1..-1//1) <> s
        else
          p <> base <> s
        end
    end
  end

  defp get_opt(opts, key) when is_map(opts), do: Map.get(opts, key)
  defp get_opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp get_opt(_other, _key), do: nil

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

  def label_text(label_opt, item, series_name, opts \\ %{}) do
    cond do
      is_function(label_opt, 2) -> label_opt.(item, series_name)
      is_function(label_opt, 1) -> label_opt.(item)
      label_opt == :value -> format_val(item.value, opts)
      label_opt in [true, :label, :top, :data] -> item.label
      is_binary(label_opt) -> label_opt
      true -> nil
    end
  end

  def label_element(item, x, y, label_opt, series_name, class_name, opts \\ %{}) do
    case label_text(label_opt, item, series_name, opts) do
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

  def axis_elements(
        bands,
        margin,
        plot_width,
        plot_height,
        min_value,
        max_value,
        ticks,
        labels,
        opts \\ %{}
      ) do
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
        &y_label(&1, margin, plot_height, min_value, max_value, opts)
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

  defp y_label(tick, margin, plot_height, min_value, max_value, opts) do
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
      [format_tick(tick, opts)]
    )
  end

  def format_tick(tick, opts \\ %{})

  def format_tick(tick, opts) when is_integer(tick) do
    decorate_val(Integer.to_string(tick), opts)
  end

  def format_tick(tick, opts) when is_float(tick) do
    rounded = Float.round(tick, 6)

    base =
      if rounded == trunc(rounded) do
        Integer.to_string(trunc(rounded))
      else
        :erlang.float_to_binary(rounded, decimals: 2)
      end

    decorate_val(base, opts)
  end

  def format_tick(tick, opts), do: decorate_val(to_string(tick), opts)

  def guide_elements(opts, margin, plot_width, plot_height, min_value, max_value) do
    max_guide =
      build_guide_line(
        opts.y_max,
        opts.y_max_guide,
        margin,
        plot_width,
        plot_height,
        min_value,
        max_value,
        "plotto-guide-line plotto-guide-line-max"
      )

    min_guide =
      build_guide_line(
        opts.y_min,
        opts.y_min_guide,
        margin,
        plot_width,
        plot_height,
        min_value,
        max_value,
        "plotto-guide-line plotto-guide-line-min"
      )

    Enum.reject([max_guide, min_guide], &is_nil/1)
  end

  defp build_guide_line(nil, _guide_opt, _margin, _w, _h, _min, _max, _class), do: nil
  defp build_guide_line(_val, false, _margin, _w, _h, _min, _max, _class), do: nil
  defp build_guide_line(_val, nil, _margin, _w, _h, _min, _max, _class), do: nil

  defp build_guide_line(
         val,
         guide_opt,
         margin,
         plot_width,
         plot_height,
         min_value,
         max_value,
         class
       ) do
    if val >= min_value and val <= max_value do
      {style, color} =
        case guide_opt do
          true -> {:dashed, Theme.axis_color()}
          {s, c} when (is_atom(s) or is_binary(s)) and is_binary(c) -> {s, c}
          c when is_binary(c) -> {:dashed, c}
        end

      y = margin.top + Axis.linear_scale(val, min_value, max_value, plot_height)

      dash_array =
        case style do
          :solid -> nil
          :dotted -> "2,4"
          :dashed -> "6,4"
          custom when is_binary(custom) -> custom
        end

      attrs =
        %{
          "x1" => to_string(margin.left),
          "y1" => to_string(y),
          "x2" => to_string(margin.left + plot_width),
          "y2" => to_string(y),
          "stroke" => color,
          "stroke-width" => to_string(Theme.stroke_width()),
          "class" => class
        }
        |> maybe_put("stroke-dasharray", dash_array)

      Element.new("line", attrs)
    else
      nil
    end
  end

  def effective_margin(margin, legend, entries) do
    effective_margin(margin, legend, entries, [], [], :vertical, %{})
  end

  def effective_margin(
        margin,
        legend,
        entries,
        ticks,
        labels,
        orientation \\ :vertical,
        opts \\ %{}
      ) do
    font_size = Theme.font_size()

    left_margin =
      case ticks do
        [] ->
          margin.left

        _ ->
          max_tick_w =
            ticks
            |> Enum.map(&format_tick(&1, opts))
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

        horizontal? =
          orientation == :horizontal and
            legend in [
              :top_left,
              :top_center,
              :top_right,
              :top,
              :bottom_left,
              :bottom_center,
              :bottom_right,
              :bottom
            ]

        case legend do
          position when position in [:top_left, :top_center, :top_right, :top] ->
            rows = if horizontal?, do: 1, else: n
            Map.update!(margin, :top, &(&1 + Theme.legend_row_height() * rows))

          position when position in [:bottom_left, :bottom_center, :bottom_right, :bottom] ->
            rows = if horizontal?, do: 1, else: n
            Map.update!(margin, :bottom, &(&1 + Theme.legend_row_height() * rows))

          position when position in [:right_top, :right_middle, :right_bottom] ->
            content_w = legend_content_width(drawable, font_size)
            Map.update!(margin, :right, &(&1 + content_w + 16))

          position when position in [:left_top, :left_middle, :left_bottom] ->
            content_w = legend_content_width(drawable, font_size)
            Map.update!(margin, :left, &(&1 + content_w + 16))
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

  def legend_elements(entries, legend, margin, width, height, orientation \\ :vertical) do
    drawable = drawable_entries(legend, entries)
    n = length(drawable)

    if n == 0 do
      []
    else
      horizontal? =
        orientation == :horizontal and
          legend in [
            :top_left,
            :top_center,
            :top_right,
            :top,
            :bottom_left,
            :bottom_center,
            :bottom_right,
            :bottom
          ]

      if horizontal? do
        horizontal_legend_elements(drawable, legend, margin, width, height)
      else
        drawable
        |> Enum.with_index()
        |> Enum.flat_map(fn {entry, i} ->
          legend_row(entry, legend, margin, width, height, i, n)
        end)
      end
    end
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
    {name, color, meta} = normalize_entry(entry)
    swatch_size = Theme.legend_swatch_size()

    swatch_width =
      Map.get(meta, :swatch_width) || if(meta[:type] == :line, do: 18, else: swatch_size)

    gap = Theme.legend_gap()
    row_height = Theme.legend_row_height()
    font_size = Theme.font_size()
    plot_width = width - margin.left - margin.right

    {y_center, swatch_x, text_x, text_anchor} =
      case legend do
        position when position in [:top_left, :top_center, :top_right, :top] ->
          anchor = margin.top
          y = anchor - row_height * (n - i - 0.5)

          case position do
            :top_left ->
              {y, margin.left, margin.left + swatch_width + gap, "start"}

            pos when pos in [:top_center, :top] ->
              row_w = swatch_width + gap + text_width(name, font_size)
              sx = margin.left + max(0.0, (plot_width - row_w) / 2)
              {y, sx, sx + swatch_width + gap, "start"}

            :top_right ->
              {y, width - margin.right - swatch_width, width - margin.right - swatch_width - gap,
               "end"}
          end

        position when position in [:bottom_left, :bottom_center, :bottom_right, :bottom] ->
          anchor = height
          y = anchor - row_height * (n - i - 0.5)

          case position do
            :bottom_left ->
              {y, margin.left, margin.left + swatch_width + gap, "start"}

            pos when pos in [:bottom_center, :bottom] ->
              row_w = swatch_width + gap + text_width(name, font_size)
              sx = margin.left + max(0.0, (plot_width - row_w) / 2)
              {y, sx, sx + swatch_width + gap, "start"}

            :bottom_right ->
              {y, width - margin.right - swatch_width, width - margin.right - swatch_width - gap,
               "end"}
          end

        position when position in [:right_top, :right_middle, :right_bottom] ->
          plot_h = height - margin.top - margin.bottom

          y =
            case position do
              :right_top ->
                margin.top + (i + 0.5) * row_height

              :right_middle ->
                margin.top + (plot_h - n * row_height) / 2 + (i + 0.5) * row_height

              :right_bottom ->
                height - margin.bottom - (n - i - 0.5) * row_height
            end

          sx = width - margin.right + 12
          tx = sx + swatch_width + gap
          {y, sx, tx, "start"}

        position when position in [:left_top, :left_middle, :left_bottom] ->
          plot_h = height - margin.top - margin.bottom

          y =
            case position do
              :left_top ->
                margin.top + (i + 0.5) * row_height

              :left_middle ->
                margin.top + (plot_h - n * row_height) / 2 + (i + 0.5) * row_height

              :left_bottom ->
                height - margin.bottom - (n - i - 0.5) * row_height
            end

          sx = 8
          tx = sx + swatch_width + gap
          {y, sx, tx, "start"}
      end

    swatch = build_swatch(meta, swatch_x, y_center, swatch_width, color)
    text = build_text(name, text_x, y_center + font_size / 2, text_anchor, font_size)

    [swatch, text]
  end

  defp horizontal_legend_elements(drawable, legend, margin, width, height) do
    font_size = Theme.font_size()
    gap = Theme.legend_gap()
    item_gap = 16
    row_height = Theme.legend_row_height()

    y_center =
      case legend do
        pos when pos in [:top_left, :top_center, :top_right, :top] ->
          margin.top - row_height * 0.5

        pos when pos in [:bottom_left, :bottom_center, :bottom_right, :bottom] ->
          height - row_height * 0.5
      end

    plot_left = margin.left
    plot_width = max(0.0, width - margin.left - margin.right)
    n = length(drawable)

    items_meta =
      Enum.map(drawable, fn entry ->
        {name, color, meta} = normalize_entry(entry)

        swatch_width =
          Map.get(meta, :swatch_width) ||
            if(meta[:type] == :line, do: 18, else: Theme.legend_swatch_size())

        tw = text_width(name, font_size)
        {name, color, meta, swatch_width, tw}
      end)

    fixed_w =
      items_meta
      |> Enum.map(fn {_name, _color, _meta, sw, _tw} -> sw + gap end)
      |> Enum.sum()
      |> Kernel.+(max(0, n - 1) * item_gap)

    avail_for_texts = max(0.0, plot_width - fixed_w)
    text_widths = Enum.map(items_meta, fn {_name, _color, _meta, _sw, tw} -> tw end)
    sum_tw = Enum.sum(text_widths)

    budgets =
      if sum_tw <= avail_for_texts do
        text_widths
      else
        allocate_text_budgets(text_widths, avail_for_texts)
      end

    prepared =
      items_meta
      |> Enum.zip(budgets)
      |> Enum.map(fn {{name, color, meta, sw, tw}, budget} ->
        display_name =
          if tw <= budget do
            name
          else
            truncate_to_width(name, budget, font_size)
          end

        actual_tw = text_width(display_name, font_size)
        item_w = sw + gap + actual_tw
        {display_name, color, meta, sw, item_w}
      end)

    total_w =
      prepared
      |> Enum.map(fn {_name, _color, _meta, _sw, item_w} -> item_w end)
      |> Enum.sum()
      |> Kernel.+(max(0, n - 1) * item_gap)

    start_x =
      case legend do
        pos when pos in [:top_left, :bottom_left] ->
          plot_left

        pos when pos in [:top_center, :bottom_center, :top, :bottom] ->
          plot_left + max(0.0, (plot_width - total_w) / 2)

        pos when pos in [:top_right, :bottom_right] ->
          plot_left + max(0.0, plot_width - total_w)
      end

    {elements, _} =
      Enum.reduce(prepared, {[], start_x}, fn {display_name, color, meta, sw, item_w},
                                              {acc_els, cur_x} ->
        swatch_x = cur_x
        text_x = swatch_x + sw + gap

        swatch = build_swatch(meta, swatch_x, y_center, sw, color)
        text = build_text(display_name, text_x, y_center + font_size / 2, "start", font_size)

        {acc_els ++ [swatch, text], cur_x + item_w + item_gap}
      end)

    elements
  end

  defp normalize_entry({name, color}), do: {name, color, %{type: :rect}}
  defp normalize_entry({name, color, meta}), do: {name, color, meta}

  defp build_swatch(meta, swatch_x, y_center, swatch_width, color) do
    swatch_size = Theme.legend_swatch_size()

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
  end

  defp build_text(name, text_x, text_y, text_anchor, font_size) do
    Element.new(
      "text",
      %{
        "x" => text_x,
        "y" => text_y,
        "text-anchor" => text_anchor,
        "font-size" => font_size,
        "fill" => Theme.text_color(),
        "class" => "plotto-legend-text"
      },
      [name]
    )
  end

  defp allocate_text_budgets(widths, total_budget) do
    n = length(widths)
    avg = total_budget / max(n, 1)
    {short, long} = Enum.split_with(widths, &(&1 <= avg))

    if short == [] or long == [] do
      List.duplicate(avg, n)
    else
      used_by_short = Enum.sum(short)
      remaining_budget = max(0.0, total_budget - used_by_short)
      remaining_avg = remaining_budget / length(long)

      Enum.map(widths, fn w ->
        if w <= avg, do: w, else: remaining_avg
      end)
    end
  end

  defp truncate_to_width(name, max_w, font_size) do
    if text_width(name, font_size) <= max_w do
      name
    else
      ellipsis = "…"
      ellipsis_w = text_width(ellipsis, font_size)
      target_w = max_w - ellipsis_w

      if target_w <= 0 do
        ellipsis
      else
        graphemes = String.graphemes(name)

        {kept, _} =
          Enum.reduce_while(graphemes, {"", 0.0}, fn g, {acc_str, acc_w} ->
            w = text_width(g, font_size)

            if acc_w + w <= target_w do
              {:cont, {acc_str <> g, acc_w + w}}
            else
              {:halt, {acc_str, acc_w}}
            end
          end)

        if kept == "", do: ellipsis, else: kept <> ellipsis
      end
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
