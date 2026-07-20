defmodule Plotto.Font.TrueTypeTest do
  use ExUnit.Case, async: true

  alias Plotto.Font.TrueType

  @font_path Path.expand("../../../fonts/DejaVuSans.ttf", __DIR__)
  @font_binary File.read!(@font_path)

  describe "table directory and header parsing" do
    test "parse_tables/1 finds all required table offsets" do
      tables = TrueType.parse_tables(@font_binary)

      assert Map.has_key?(tables, "head")
      assert Map.has_key?(tables, "hhea")
      assert Map.has_key?(tables, "maxp")
      assert Map.has_key?(tables, "hmtx")
      assert Map.has_key?(tables, "loca")
      assert Map.has_key?(tables, "glyf")
      assert Map.has_key?(tables, "cmap")
    end

    test "parse_head/1 reads units_per_em and index_to_loc_format" do
      tables = TrueType.parse_tables(@font_binary)
      head = TrueType.parse_head(TrueType.table_data(@font_binary, tables, "head"))

      assert head.units_per_em == 2048
    end

    test "parse_maxp/1 reads the glyph count" do
      tables = TrueType.parse_tables(@font_binary)
      maxp = TrueType.parse_maxp(TrueType.table_data(@font_binary, tables, "maxp"))

      assert maxp.num_glyphs == 6253
    end

    test "parse_hhea/1 reads num_of_long_hor_metrics" do
      tables = TrueType.parse_tables(@font_binary)
      hhea = TrueType.parse_hhea(TrueType.table_data(@font_binary, tables, "hhea"))

      assert hhea.num_of_long_hor_metrics > 0
    end
  end

  describe "hmtx parsing" do
    test "parse_hmtx/3 returns glyph id 36's advance width matching 'A'" do
      tables = TrueType.parse_tables(@font_binary)
      head = TrueType.parse_head(TrueType.table_data(@font_binary, tables, "head"))
      hhea = TrueType.parse_hhea(TrueType.table_data(@font_binary, tables, "hhea"))
      maxp = TrueType.parse_maxp(TrueType.table_data(@font_binary, tables, "maxp"))

      hmtx =
        TrueType.parse_hmtx(
          TrueType.table_data(@font_binary, tables, "hmtx"),
          hhea.num_of_long_hor_metrics,
          maxp.num_glyphs
        )

      assert map_size(hmtx) == maxp.num_glyphs
      assert hmtx[36] == 1401
      refute head == nil
    end
  end

  describe "cmap parsing" do
    test "parse_cmap/1 maps 'A' (U+0041) to glyph id 36" do
      tables = TrueType.parse_tables(@font_binary)
      cmap = TrueType.parse_cmap(TrueType.table_data(@font_binary, tables, "cmap"))

      assert cmap[?A] == 36
    end

    test "parse_cmap/1 maps a large set of Latin characters" do
      tables = TrueType.parse_tables(@font_binary)
      cmap = TrueType.parse_cmap(TrueType.table_data(@font_binary, tables, "cmap"))

      assert map_size(cmap) > 1000
      assert Map.has_key?(cmap, ?e)
      assert Map.has_key?(cmap, 0x00E9)
      assert Map.has_key?(cmap, 0x00F1)
    end
  end
end
