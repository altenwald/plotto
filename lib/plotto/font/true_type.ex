defmodule Plotto.Font.TrueType do
  @moduledoc false

  import Bitwise

  defstruct [:units_per_em, :glyphs, :cmap, :missing_glyph_advance]

  # glyf simple-glyph point flags
  @on_curve_point 0x01
  @x_short_vector 0x02
  @y_short_vector 0x04
  @repeat_flag 0x08
  @x_is_same_or_positive 0x10
  @y_is_same_or_positive 0x20

  # glyf composite-glyph component flags
  @arg_1_and_2_are_words 0x0001
  @args_are_xy_values 0x0002
  @we_have_a_scale 0x0008
  @more_components 0x0020
  @we_have_an_x_and_y_scale 0x0040
  @we_have_a_two_by_two 0x0080

  def parse_tables(
        <<_version::32, num_tables::16, _search_range::16, _entry_selector::16, _range_shift::16,
          rest::binary>>
      ) do
    parse_table_entries(rest, num_tables, %{})
  end

  defp parse_table_entries(_binary, 0, acc), do: acc

  defp parse_table_entries(
         <<tag::binary-size(4), _checksum::32, offset::32, length::32, rest::binary>>,
         count,
         acc
       ) do
    parse_table_entries(rest, count - 1, Map.put(acc, tag, {offset, length}))
  end

  def table_data(binary, tables, tag) do
    {offset, length} = Map.fetch!(tables, tag)
    binary_part(binary, offset, length)
  end

  def parse_head(
        <<_major::16, _minor::16, _revision::32, _checksum_adj::32, _magic::32, _flags::16,
          units_per_em::16, _created::64, _modified::64, _x_min::16-signed, _y_min::16-signed,
          _x_max::16-signed, _y_max::16-signed, _mac_style::16, _lowest_rec_ppem::16,
          _font_direction_hint::16-signed, index_to_loc_format::16-signed,
          _glyph_data_format::16-signed>>
      ) do
    %{units_per_em: units_per_em, index_to_loc_format: index_to_loc_format}
  end

  def parse_hhea(
        <<_version::32, _ascent::16-signed, _descent::16-signed, _line_gap::16-signed,
          _advance_width_max::16, _min_lsb::16-signed, _min_rsb::16-signed,
          _x_max_extent::16-signed, _caret_slope_rise::16-signed, _caret_slope_run::16-signed,
          _caret_offset::16-signed, _reserved::64, _metric_format::16-signed,
          num_of_long_hor_metrics::16>>
      ) do
    %{num_of_long_hor_metrics: num_of_long_hor_metrics}
  end

  def parse_maxp(<<_version::32, num_glyphs::16, _rest::binary>>) do
    %{num_glyphs: num_glyphs}
  end

  def parse_loca(binary, 0, num_glyphs) do
    for(<<offset::16 <- binary>>, do: offset * 2) |> Enum.take(num_glyphs + 1)
  end

  def parse_loca(binary, 1, num_glyphs) do
    for(<<offset::32 <- binary>>, do: offset) |> Enum.take(num_glyphs + 1)
  end

  def parse_hmtx(binary, num_of_long_hor_metrics, num_glyphs) do
    {long_metrics, rest} = parse_long_hmetrics(binary, num_of_long_hor_metrics, [])
    extra_count = num_glyphs - num_of_long_hor_metrics
    extra_lsbs = parse_extra_lsbs(rest, extra_count, [])

    last_advance = if long_metrics == [], do: 0, else: elem(List.last(long_metrics), 0)

    long_map =
      long_metrics
      |> Enum.with_index()
      |> Map.new(fn {{advance, _lsb}, index} -> {index, advance} end)

    extra_map =
      extra_lsbs
      |> Enum.with_index(num_of_long_hor_metrics)
      |> Map.new(fn {_lsb, index} -> {index, last_advance} end)

    Map.merge(long_map, extra_map)
  end

  defp parse_long_hmetrics(binary, 0, acc), do: {Enum.reverse(acc), binary}

  defp parse_long_hmetrics(<<advance::16, lsb::16-signed, rest::binary>>, count, acc) do
    parse_long_hmetrics(rest, count - 1, [{advance, lsb} | acc])
  end

  defp parse_extra_lsbs(_binary, 0, acc), do: Enum.reverse(acc)

  defp parse_extra_lsbs(<<lsb::16-signed, rest::binary>>, count, acc) do
    parse_extra_lsbs(rest, count - 1, [lsb | acc])
  end

  def parse_cmap(<<_version::16, num_tables::16, rest::binary>>) do
    encoding_records = parse_cmap_encoding_records(rest, num_tables, [])

    {_platform, _encoding, offset} =
      Enum.find(encoding_records, List.first(encoding_records), fn {platform, encoding, _offset} ->
        platform == 3 and encoding == 1
      end)

    subtable = binary_part(rest, offset - 4, byte_size(rest) - (offset - 4))
    parse_cmap_format4(subtable)
  end

  defp parse_cmap_encoding_records(_binary, 0, acc), do: Enum.reverse(acc)

  defp parse_cmap_encoding_records(
         <<platform::16, encoding::16, offset::32, rest::binary>>,
         count,
         acc
       ) do
    parse_cmap_encoding_records(rest, count - 1, [{platform, encoding, offset} | acc])
  end

  defp parse_cmap_format4(
         <<4::16, _length::16, _language::16, seg_count_x2::16, _search_range::16,
           _entry_selector::16, _range_shift::16, rest::binary>>
       ) do
    seg_count = div(seg_count_x2, 2)
    {end_codes, rest} = take_uint16_list(rest, seg_count)
    <<_reserved_pad::16, rest::binary>> = rest
    {start_codes, rest} = take_uint16_list(rest, seg_count)
    {id_deltas, rest} = take_int16_list(rest, seg_count)
    {id_range_offsets, glyph_id_array_binary} = take_uint16_list(rest, seg_count)

    build_cmap(end_codes, start_codes, id_deltas, id_range_offsets, glyph_id_array_binary)
  end

  defp take_uint16_list(binary, count) do
    <<values::binary-size(count * 2), rest::binary>> = binary
    {for(<<v::16 <- values>>, do: v), rest}
  end

  defp take_int16_list(binary, count) do
    <<values::binary-size(count * 2), rest::binary>> = binary
    {for(<<v::16-signed <- values>>, do: v), rest}
  end

  defp build_cmap(end_codes, start_codes, id_deltas, id_range_offsets, glyph_id_array_binary) do
    segments = Enum.zip([end_codes, start_codes, id_deltas, id_range_offsets])
    seg_count = Enum.count(segments)

    segments
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{end_code, start_code, id_delta, id_range_offset}, seg_index}, acc ->
      Enum.reduce(start_code..end_code, acc, fn code, acc ->
        if code == 0xFFFF do
          acc
        else
          glyph_id =
            resolve_glyph_id(
              code,
              start_code,
              id_delta,
              id_range_offset,
              seg_index,
              seg_count,
              glyph_id_array_binary
            )

          if glyph_id == 0, do: acc, else: Map.put(acc, code, glyph_id)
        end
      end)
    end)
  end

  defp resolve_glyph_id(
         code,
         _start_code,
         id_delta,
         0,
         _seg_index,
         _seg_count,
         _glyph_id_array_binary
       ) do
    rem(code + id_delta, 65536)
  end

  defp resolve_glyph_id(
         code,
         start_code,
         id_delta,
         id_range_offset,
         seg_index,
         seg_count,
         glyph_id_array_binary
       ) do
    offset_in_array = id_range_offset + 2 * (code - start_code) - 2 * (seg_count - seg_index)

    case glyph_id_array_binary do
      <<_skip::binary-size(offset_in_array), glyph_index::16, _rest::binary>>
      when offset_in_array >= 0 ->
        if glyph_index == 0, do: 0, else: rem(glyph_index + id_delta, 65536)

      _ ->
        0
    end
  end

  def parse!(binary) do
    tables = parse_tables(binary)
    head = parse_head(table_data(binary, tables, "head"))
    hhea = parse_hhea(table_data(binary, tables, "hhea"))
    maxp = parse_maxp(table_data(binary, tables, "maxp"))

    loca =
      table_data(binary, tables, "loca")
      |> parse_loca(head.index_to_loc_format, maxp.num_glyphs)
      |> List.to_tuple()

    glyf_data = table_data(binary, tables, "glyf")

    hmtx =
      parse_hmtx(
        table_data(binary, tables, "hmtx"),
        hhea.num_of_long_hor_metrics,
        maxp.num_glyphs
      )

    cmap = parse_cmap(table_data(binary, tables, "cmap"))

    glyphs =
      Map.new(0..(maxp.num_glyphs - 1), fn glyph_id ->
        outline = parse_glyph_outline(glyf_data, loca, glyph_id)
        advance_width = Map.get(hmtx, glyph_id, 0)
        {glyph_id, %{outline: outline, advance_width: advance_width}}
      end)

    %__MODULE__{
      units_per_em: head.units_per_em,
      glyphs: glyphs,
      cmap: cmap,
      missing_glyph_advance: Map.get(hmtx, 0, 0)
    }
  end

  def lookup_glyph(%__MODULE__{cmap: cmap, glyphs: glyphs}, codepoint) do
    with glyph_id when not is_nil(glyph_id) <- Map.get(cmap, codepoint) do
      Map.get(glyphs, glyph_id)
    end
  end

  def parse_glyph_outline(glyf_data, loca, glyph_id) do
    case glyph_bytes(glyf_data, loca, glyph_id) do
      <<>> ->
        []

      <<num_contours::16-signed, _bbox::64, rest::binary>> when num_contours >= 0 ->
        parse_simple_outline(num_contours, rest)

      <<_num_contours::16-signed, _bbox::64, rest::binary>> ->
        parse_composite_outline(rest, glyf_data, loca)
    end
  end

  defp glyph_bytes(glyf_data, loca, glyph_id) do
    start_offset = elem(loca, glyph_id)
    end_offset = elem(loca, glyph_id + 1)

    if end_offset > start_offset do
      binary_part(glyf_data, start_offset, end_offset - start_offset)
    else
      <<>>
    end
  end

  defp parse_simple_outline(0, _rest), do: []

  defp parse_simple_outline(num_contours, rest) when num_contours > 0 do
    {end_pts, rest} = take_uint16_list(rest, num_contours)
    num_points = List.last(end_pts) + 1
    <<instruction_length::16, rest::binary>> = rest
    <<_instructions::binary-size(instruction_length), rest::binary>> = rest
    {flags, rest} = parse_glyph_flags(rest, num_points, [])
    {x_coords, rest} = parse_glyph_coords(rest, flags, @x_short_vector, @x_is_same_or_positive)
    {y_coords, _rest} = parse_glyph_coords(rest, flags, @y_short_vector, @y_is_same_or_positive)

    points =
      Enum.zip([x_coords, y_coords, flags])
      |> Enum.map(fn {x, y, flag} -> %{x: x, y: y, on_curve: (flag &&& @on_curve_point) == 1} end)

    split_into_contours(points, end_pts)
  end

  defp parse_glyph_flags(binary, remaining, acc) when remaining <= 0,
    do: {Enum.reverse(acc), binary}

  defp parse_glyph_flags(<<flag::8, rest::binary>>, remaining, acc) do
    if (flag &&& @repeat_flag) != 0 do
      <<repeat::8, rest::binary>> = rest
      flags = List.duplicate(flag, repeat + 1)
      parse_glyph_flags(rest, remaining - (repeat + 1), Enum.reverse(flags) ++ acc)
    else
      parse_glyph_flags(rest, remaining - 1, [flag | acc])
    end
  end

  defp parse_glyph_coords(binary, flags, short_flag, same_or_positive_flag) do
    {deltas, rest} =
      Enum.reduce(flags, {[], binary}, fn flag, {acc, bin} ->
        cond do
          (flag &&& short_flag) != 0 ->
            <<value::8, rest::binary>> = bin
            sign = if (flag &&& same_or_positive_flag) != 0, do: 1, else: -1
            {[value * sign | acc], rest}

          (flag &&& same_or_positive_flag) != 0 ->
            {[0 | acc], bin}

          true ->
            <<value::16-signed, rest::binary>> = bin
            {[value | acc], rest}
        end
      end)

    coords = deltas |> Enum.reverse() |> Enum.scan(0, fn delta, acc -> acc + delta end)
    {coords, rest}
  end

  defp split_into_contours(points, end_pts) do
    {contours, _} =
      Enum.reduce(end_pts, {[], 0}, fn end_pt, {acc, start_index} ->
        contour = Enum.slice(points, start_index, end_pt - start_index + 1)
        {[contour | acc], end_pt + 1}
      end)

    Enum.reverse(contours)
  end

  defp parse_composite_outline(binary, glyf_data, loca) do
    parse_components(binary, glyf_data, loca, [])
  end

  defp parse_components(<<flags::16, glyph_index::16, rest::binary>>, glyf_data, loca, acc) do
    {dx, dy, rest} = parse_component_args(rest, flags)
    {a, b, c, d, rest} = parse_component_transform(rest, flags)

    # A composite glyph's component may itself be simple or composite —
    # resolve it by recursing back into the top-level outline parser.
    component_outline =
      glyf_data
      |> parse_glyph_outline(loca, glyph_index)
      |> transform_contours(a, b, c, d, dx, dy)

    acc = acc ++ component_outline

    if (flags &&& @more_components) != 0 do
      parse_components(rest, glyf_data, loca, acc)
    else
      acc
    end
  end

  defp parse_component_args(binary, flags) do
    words? = (flags &&& @arg_1_and_2_are_words) != 0
    xy_values? = (flags &&& @args_are_xy_values) != 0

    case {words?, xy_values?} do
      {true, true} ->
        then_binary(binary, fn <<dx::16-signed, dy::16-signed, rest::binary>> ->
          {dx, dy, rest}
        end)

      {false, true} ->
        then_binary(binary, fn <<dx::8-signed, dy::8-signed, rest::binary>> -> {dx, dy, rest} end)

      {true, false} ->
        then_binary(binary, fn <<_p1::16, _p2::16, rest::binary>> -> {0, 0, rest} end)

      {false, false} ->
        then_binary(binary, fn <<_p1::8, _p2::8, rest::binary>> -> {0, 0, rest} end)
    end
  end

  defp then_binary(binary, fun), do: fun.(binary)

  defp parse_component_transform(binary, flags) do
    cond do
      (flags &&& @we_have_a_scale) != 0 ->
        <<scale::16-signed, rest::binary>> = binary
        s = f2dot14(scale)
        {s, 0, 0, s, rest}

      (flags &&& @we_have_an_x_and_y_scale) != 0 ->
        <<x_scale::16-signed, y_scale::16-signed, rest::binary>> = binary
        {f2dot14(x_scale), 0, 0, f2dot14(y_scale), rest}

      (flags &&& @we_have_a_two_by_two) != 0 ->
        <<a::16-signed, b::16-signed, c::16-signed, d::16-signed, rest::binary>> = binary
        {f2dot14(a), f2dot14(b), f2dot14(c), f2dot14(d), rest}

      true ->
        {1.0, 0.0, 0.0, 1.0, binary}
    end
  end

  defp f2dot14(value), do: value / 16384

  defp transform_contours(contours, a, b, c, d, dx, dy) do
    Enum.map(contours, fn contour ->
      Enum.map(contour, fn point ->
        %{
          x: round(a * point.x + c * point.y + dx),
          y: round(b * point.x + d * point.y + dy),
          on_curve: point.on_curve
        }
      end)
    end)
  end
end
