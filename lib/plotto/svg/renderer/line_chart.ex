defmodule Plotto.SVG.Renderer.LineChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, LineData, Theme}

  def render(%Plotto.LineChart{data: data, opts: opts}) do
    x_mode? = LineData.x_mode?(data)
    data = if x_mode?, do: label_items(data, opts), else: data

    entries =
      data
      |> Enum.with_index()
      |> Enum.map(fn {series, index} -> legend_entry(series, index, opts) end)

    {x_scale, labels} = x_axis(data, x_mode?, opts)

    all_values =
      Enum.flat_map(data, fn series -> Enum.flat_map(series.data, &values_of(series, &1)) end)

    data_min = Enum.min(all_values)
    data_max = Enum.max(all_values)
    {raw_min, raw_max} = Axis.calculate_y_domain(data_min, data_max, opts)
    ticks = Axis.ticks(raw_min, raw_max)
    min_value = List.first(ticks)
    max_value = List.last(ticks)

    inline? = Map.get(opts, :inline, false) == true

    margin =
      if inline? do
        Theme.inline_margin()
      else
        Shared.effective_margin(
          Theme.margin(),
          opts.legend,
          entries,
          ticks,
          labels,
          opts.legend_orientation,
          opts
        )
      end

    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    bands = x_scale.bands.(plot_width)
    positions = x_scale.positions.(plot_width)
    x_of = fn item -> margin.left + Map.fetch!(positions, slot_key(item)) end

    multi_series? = length(data) > 1

    {ranges, polylines, point_elements, label_elements} =
      data
      |> Enum.with_index()
      |> Enum.reduce({[], [], [], []}, fn {series, index},
                                          {acc_ranges, acc_lines, acc_pts, acc_lbls} ->
        color = series_color(series, index, opts)

        if range?(series) do
          band = build_range(series, color, x_of, min_value, max_value, margin, plot_height)
          {acc_ranges ++ [band], acc_lines, acc_pts, acc_lbls}
        else
          {polyline, pts, lbls} =
            draw_line(
              series,
              index,
              x_of,
              {min_value, max_value},
              margin,
              plot_height,
              multi_series?,
              opts
            )

          {acc_ranges, acc_lines ++ [polyline], acc_pts ++ pts, acc_lbls ++ lbls}
        end
      end)

    legend =
      Shared.legend_elements(
        entries,
        opts.legend,
        margin,
        opts.width,
        opts.height,
        opts.legend_orientation
      )

    guides =
      Shared.guide_elements(
        opts,
        margin,
        plot_width,
        plot_height,
        min_value,
        max_value
      )

    children =
      if inline? do
        ranges ++
          polylines ++ hover_elements(data, x_scale, margin, plot_width, plot_height, opts)
      else
        Shared.axis_elements(
          bands,
          margin,
          plot_width,
          plot_height,
          min_value,
          max_value,
          ticks,
          labels,
          opts
        ) ++
          guides ++
          ranges ++
          polylines ++
          point_elements ++
          label_elements ++
          Shared.title_elements(opts.title, opts.width) ++
          legend ++
          hover_elements(data, x_scale, margin, plot_width, plot_height, opts)
      end

    Shared.svg_root(opts.width, opts.height, children, opts)
  end

  defp range?(series), do: Map.get(series, :type) == :range

  defp series_color(series, index, opts),
    do: Map.get(series, :color) || Theme.color(opts.colors, index)

  defp legend_entry(series, index, opts) do
    color = series_color(series, index, opts)

    if range?(series) do
      {series.name, color, %{type: :range}}
    else
      %{swatch_dash: dash, stroke_width: width} = line_style(series, index, opts, {"2,3", "4,2"})
      {series.name, color, %{type: :line, stroke_dasharray: dash, stroke_width: width}}
    end
  end

  # The dash pattern and width of a line. The legend swatch and the line itself use different patterns for the
  # `:dotted`/`:dashed` shorthands, hence `{dotted, dashed}`.
  defp line_style(series, index, opts, {dotted_pattern, dashed_pattern}) do
    opt_style = Enum.at(Map.get(opts, :line_styles, []), index)

    dotted? =
      Map.get(series, :dotted, false) || Map.get(series, :style) == :dotted ||
        opt_style == :dotted

    dashed? =
      Map.get(series, :dashed, false) || Map.get(series, :style) == :dashed ||
        opt_style == :dashed

    dash =
      Map.get(series, :stroke_dasharray) ||
        cond do
          is_binary(opt_style) -> opt_style
          dotted? -> dotted_pattern
          dashed? -> dashed_pattern
          true -> nil
        end

    width =
      Map.get(series, :stroke_width) || Map.get(series, :line_width) ||
        Map.get(opts, :stroke_width) ||
        Theme.stroke_width()

    %{swatch_dash: dash, stroke_width: width}
  end

  defp draw_line(
         series,
         index,
         x_of,
         {min_value, max_value},
         margin,
         plot_height,
         multi_series?,
         opts
       ) do
    color = series_color(series, index, opts)

    %{swatch_dash: dash_array, stroke_width: width} =
      line_style(series, index, opts, {"2,4", "6,4"})

    points =
      Enum.map(series.data, fn item ->
        {item, x_of.(item),
         margin.top + Axis.linear_scale(item.value, min_value, max_value, plot_height)}
      end)

    circles =
      if opts.points == false do
        []
      else
        Enum.map(
          points,
          &build_point_circle(&1, color, opts.tooltip, series.name, multi_series?, opts)
        )
      end

    {build_polyline(points, color, dash_array, width), circles,
     build_point_labels(points, opts.label, series.name, opts)}
  end

  defp values_of(series, item) do
    if range?(series), do: [item.min, item.max], else: [item.value]
  end

  # Points placed by `:x` get the text of their position as `:label`, which is what titles and labels read.
  defp label_items(data, opts) do
    Enum.map(data, fn series ->
      %{series | data: Enum.map(series.data, &Map.put_new(&1, :label, x_text(&1.x, opts, :full)))}
    end)
  end

  # The x axis: a map with `bands` (the marks the axis writes, given the plot width), `positions` (where each item
  # goes, relative to the plot, by its slot key) and `slots` (the columns the hover divides the plot in), plus the axis labels.
  defp x_axis(data, false, _opts) do
    labels = ordered_labels(data)

    scale = %{
      bands: fn plot_width -> Axis.categorical_scale(labels, plot_width) end,
      positions: fn plot_width ->
        Map.new(Axis.categorical_scale(labels, plot_width), &{&1.label, &1.x})
      end,
      slots: fn plot_width ->
        Enum.map(
          Axis.categorical_scale(labels, plot_width),
          &{&1.label, &1.band_x, &1.band_width}
        )
      end
    }

    {scale, labels}
  end

  defp x_axis(data, true, opts) do
    xs =
      data
      |> Enum.flat_map(fn series -> Enum.map(series.data, & &1.x) end)
      |> Enum.uniq()
      |> Enum.sort()

    {first, last} = {List.first(xs), List.last(xs)}

    marks =
      case Map.get(opts, :x_scale, :linear) do
        :time -> Axis.time_ticks(first, last)
        _ -> linear_marks(first, last)
      end

    step = Axis.time_step(marks)
    labels = Enum.map(marks, &x_text(&1, opts, {:tick, step}))

    place = fn x, plot_width ->
      if last == first, do: plot_width / 2, else: (x - first) / (last - first) * plot_width
    end

    scale = %{
      bands: fn plot_width ->
        for {mark, label} <- Enum.zip(marks, labels) do
          %{
            label: label,
            x: place.(mark, plot_width),
            band_x: place.(mark, plot_width),
            band_width: 0
          }
        end
      end,
      positions: fn plot_width -> Map.new(xs, &{&1, place.(&1, plot_width)}) end,
      slots: fn plot_width ->
        centers = Enum.map(xs, &place.(&1, plot_width))
        edges = [0 | Enum.zip_with(centers, tl(centers) ++ [plot_width], &((&1 + &2) / 2))]
        edges = Enum.slice(edges, 0, length(xs)) |> Enum.zip(tl(edges) ++ [plot_width])

        for {{from, to}, x} <- Enum.zip(edges, xs), do: {x, from, max(to - from, 1)}
      end
    }

    {scale, labels}
  end

  defp linear_marks(first, last) when first == last, do: [first]

  defp linear_marks(first, last) do
    case Enum.filter(Axis.ticks(first, last, 6), &(&1 >= first and &1 <= last)) do
      [] -> [first, last]
      marks -> marks
    end
  end

  # The text of a position on the x axis: `x_format` if given; otherwise a UTC date for `x_scale: :time` (seconds
  # since the Unix epoch) and the number for a linear scale. `:full` is for titles, `{:tick, step}` for the axis.
  defp x_text(x, %{x_format: fun}, _kind) when is_function(fun, 1), do: to_string(fun.(x))

  defp x_text(x, %{x_scale: :time}, kind) do
    datetime = DateTime.from_unix!(trunc(x))

    case kind do
      :full -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
      {:tick, step} when step >= 86_400 -> Calendar.strftime(datetime, "%m-%d")
      {:tick, _step} -> Calendar.strftime(datetime, "%H:%M")
    end
  end

  defp x_text(x, opts, _kind), do: Shared.format_tick(x, Map.drop(opts, [:y_format]))

  defp build_range(series, color, x_of, min_value, max_value, margin, plot_height) do
    y = fn value -> margin.top + Axis.linear_scale(value, min_value, max_value, plot_height) end

    upper = Enum.map(series.data, &{x_of.(&1), y.(&1.max)})
    lower = series.data |> Enum.map(&{x_of.(&1), y.(&1.min)}) |> Enum.reverse()

    points = Enum.map_join(upper ++ lower, " ", fn {x, y} -> "#{fmt(x)},#{fmt(y)}" end)

    Element.new("polygon", %{
      "points" => points,
      "fill" => color,
      "fill-opacity" => fmt(Map.get(series, :opacity, 0.2)),
      "stroke" => "none",
      "class" => "plotto-range"
    })
  end

  # `hover: :column`: one invisible strip per position of the x axis whose native tooltip lists every series there,
  # so one hover reads them all together.
  defp hover_elements(data, x_scale, margin, plot_width, plot_height, %{hover: :column} = opts) do
    for {key, from, width} <- x_scale.slots.(plot_width) do
      lines =
        for series <- data, item <- Enum.filter(series.data, &(slot_key(&1) == key)) do
          name = if series.name, do: series.name <> ": ", else: ""

          if range?(series) do
            name <>
              Shared.format_val(item.min, opts) <> " – " <> Shared.format_val(item.max, opts)
          else
            name <> Shared.format_val(item.value, opts)
          end
        end

      header =
        data
        |> Enum.flat_map(& &1.data)
        |> Enum.find(&(slot_key(&1) == key))
        |> header_text(key, opts)

      Element.new(
        "rect",
        %{
          "x" => margin.left + from,
          "y" => margin.top,
          "width" => width,
          "height" => plot_height,
          "fill" => "#000000",
          "fill-opacity" => "0",
          "pointer-events" => "all",
          "class" => "plotto-hover"
        },
        [Element.new("title", %{}, [Enum.join([header | lines], "\n")])]
      )
    end
  end

  defp hover_elements(_data, _x_scale, _margin, _plot_width, _plot_height, _opts), do: []

  defp slot_key(%{x: x}), do: x
  defp slot_key(%{label: label}), do: label

  defp header_text(%{label: label}, _key, _opts), do: label
  defp header_text(_item, key, _opts), do: to_string(key)

  defp ordered_labels(data) do
    data
    |> Enum.map(fn series -> Enum.map(series.data, & &1.label) end)
    |> merge_label_lists()
  end

  defp merge_label_lists([]), do: []

  defp merge_label_lists([first | rest]) do
    Enum.reduce(rest, first, &merge_two_label_lists/2)
  end

  defp merge_two_label_lists(incoming, base) do
    Enum.reduce(incoming, base, fn label, acc ->
      if label in acc do
        acc
      else
        case find_insertion_index(incoming, label, acc) do
          nil -> acc ++ [label]
          idx -> List.insert_at(acc, idx, label)
        end
      end
    end)
  end

  defp find_insertion_index(incoming, label, acc) do
    idx_in_incoming = Enum.find_index(incoming, &(&1 == label))
    following = Enum.slice(incoming, (idx_in_incoming + 1)..-1//1)

    case Enum.find_value(following, &Enum.find_index(acc, fn x -> x == &1 end)) do
      nil -> nil
      acc_idx -> acc_idx
    end
  end

  defp build_point_labels(points, label_opt, series_name, opts) do
    Enum.flat_map(points, fn {item, x, y} ->
      label_y = y - 7

      case Shared.label_element(
             item,
             x,
             label_y,
             label_opt,
             series_name,
             "plotto-label plotto-label-point",
             opts
           ) do
        nil -> []
        label_el -> [label_el]
      end
    end)
  end

  defp build_polyline(points, color, dash_array, stroke_width) do
    points_attr = Enum.map_join(points, " ", fn {_item, x, y} -> "#{fmt(x)},#{fmt(y)}" end)

    attrs =
      %{
        "points" => points_attr,
        "fill" => "none",
        "stroke" => color,
        "stroke-width" => fmt(stroke_width),
        "class" => "plotto-line"
      }
      |> maybe_put("stroke-dasharray", dash_array)

    Element.new("polyline", attrs)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp fmt(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp fmt(v), do: to_string(v)

  defp build_point_circle({item, x, y}, color, tooltip_opt, series_name, multi_series?, opts) do
    default_title =
      if multi_series? and series_name do
        "#{series_name} - #{item.label}: #{Shared.format_val(item.value, opts)}"
      else
        "#{item.label}: #{Shared.format_val(item.value, opts)}"
      end

    base_attrs =
      %{
        "cx" => x,
        "cy" => y,
        "r" => 3,
        "fill" => color,
        "class" => "plotto-point"
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    {attrs, children} =
      Shared.apply_tooltip(base_attrs, default_title, tooltip_opt, item, series_name)

    Element.new("circle", attrs, children)
  end
end
