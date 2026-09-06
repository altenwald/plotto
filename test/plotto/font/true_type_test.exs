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
      assert is_map(head)
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

  describe "glyph outline parsing" do
    setup do
      tables = TrueType.parse_tables(@font_binary)
      head = TrueType.parse_head(TrueType.table_data(@font_binary, tables, "head"))
      maxp = TrueType.parse_maxp(TrueType.table_data(@font_binary, tables, "maxp"))

      loca =
        TrueType.parse_loca(
          TrueType.table_data(@font_binary, tables, "loca"),
          head.index_to_loc_format,
          maxp.num_glyphs
        )
        |> List.to_tuple()

      glyf_data = TrueType.table_data(@font_binary, tables, "glyf")

      {:ok, glyf_data: glyf_data, loca: loca}
    end

    test "parse_glyph_outline/3 returns 2 contours for 'A' (glyph id 36, a simple glyph)", %{
      glyf_data: glyf_data,
      loca: loca
    } do
      outline = TrueType.parse_glyph_outline(glyf_data, loca, 36)
      assert length(outline) == 2
    end

    test "parse_glyph_outline/3 returns 3 contours for 'é' (glyph id 171, a composite glyph)", %{
      glyf_data: glyf_data,
      loca: loca
    } do
      outline = TrueType.parse_glyph_outline(glyf_data, loca, 171)
      assert length(outline) == 3
    end

    test "parse_glyph_outline/3 returns 2 contours for 'ñ' (glyph id 179, a composite glyph)", %{
      glyf_data: glyf_data,
      loca: loca
    } do
      outline = TrueType.parse_glyph_outline(glyf_data, loca, 179)
      assert length(outline) == 2
    end

    test "parse_glyph_outline/3 returns [] for an empty glyph (e.g. space)", %{
      glyf_data: glyf_data,
      loca: loca
    } do
      space_glyph_id = 3
      assert TrueType.parse_glyph_outline(glyf_data, loca, space_glyph_id) == []
    end
  end

  describe "parse!/1" do
    test "assembles a full TrueType struct from the embedded font" do
      font = TrueType.parse!(@font_binary)

      assert font.units_per_em == 2048
      assert map_size(font.glyphs) == 6253
      assert font.cmap[?A] == 36
    end

    test "lookup_glyph/2 finds 'A' by codepoint" do
      font = TrueType.parse!(@font_binary)
      glyph = TrueType.lookup_glyph(font, ?A)

      assert length(glyph.outline) == 2
      assert glyph.advance_width == 1401
    end

    test "lookup_glyph/2 finds 'é' (composite) by codepoint" do
      font = TrueType.parse!(@font_binary)
      glyph = TrueType.lookup_glyph(font, 0x00E9)

      assert length(glyph.outline) == 3
    end

    test "lookup_glyph/2 returns nil for a codepoint not in the font" do
      font = TrueType.parse!(@font_binary)
      assert TrueType.lookup_glyph(font, 0x1F600) == nil
    end
  end
end
