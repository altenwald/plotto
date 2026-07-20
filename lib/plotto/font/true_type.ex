defmodule Plotto.Font.TrueType do
  @moduledoc false

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
end
