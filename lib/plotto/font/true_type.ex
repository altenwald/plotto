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
end
