# PNG Export Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `Plotto.to_png/1` and `Plotto.to_png!/1`, rendering any `Plotto.BarChart`/`Plotto.LineChart` to a PNG binary using only Elixir/Erlang standard capabilities — a TrueType parser, a glyph rasterizer, a shape rasterizer, and a PNG encoder, no external binaries or NIFs.

**Architecture:** Reuses the existing `Plotto.SVG.Renderer`/`Plotto.SVG.Element` tree unchanged. `Plotto.PNG.Rasterizer` walks that tree and draws onto a `Plotto.PNG.Canvas` at 4x the final resolution (supersampling for anti-aliasing), using a DejaVu Sans TrueType font parsed once at compile time and embedded as a literal term. `Plotto.PNG.Canvas.downsample/1` reduces to final resolution, then `Plotto.PNG.Encoder` serializes to a PNG binary.

**Tech Stack:** Elixir ~> 1.17, `:array` (pixel buffer), `:zlib` (DEFLATE), `:erlang.crc32/1` (PNG chunk CRCs). No new Hex dependencies.

**Related spec:** `docs/superpowers/specs/2026-07-19-png-export-pipeline-design.md` (supersedes the PNG-related sections of `docs/superpowers/specs/2026-07-17-core-chart-slice-design.md`).

---

## Conventions used throughout this plan

- Run a single test file with: `mix test path/to/file_test.exs`
- Run the whole suite with: `mix test`
- All new modules in this plan are internal (`@moduledoc false`) except `Plotto` itself (its `to_png/1`/`to_png!/1` additions).
- Supersampling factor: **4x**. Every task that draws onto a `Plotto.PNG.Canvas` receives coordinates already scaled by this factor by its caller — see Task 9/10 for exactly where that scaling happens.
- The pixel format is a packed 32-bit integer `0xRRGGBBAA` (red, green, blue, alpha, 8 bits each), built via `Plotto.PNG.Canvas.pack/4`.
- `Plotto.SVG.Element` attrs are always **strings** (the existing `Element.new/3` stringifies everything for the XML serializer). Every numeric attribute the Rasterizer reads (`"56"`, `"113.50"`, etc.) must be parsed back with `Float.parse/1`, which correctly handles both integer-looking and decimal strings (verified: `Float.parse("56")` → `{56.0, ""}`).
- The `fonts/DejaVuSans.ttf` asset is already committed at the project root (commit `3aa96a2`) — **not** under `priv/`, since it is only read at compile time (see Task 7). You do not need to obtain or place this file; it already exists.

---

### Task 1: `Plotto.PNG.Canvas` — pixel buffer and drawing primitives

**Files:**
- Create: `lib/plotto/png/canvas.ex`
- Test: `test/plotto/png/canvas_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.PNG.CanvasTest do
  use ExUnit.Case, async: true

  alias Plotto.PNG.Canvas

  test "new/2 creates a canvas filled with opaque white" do
    canvas = Canvas.new(3, 2)
    assert canvas.width == 3
    assert canvas.height == 2
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
    assert Canvas.get_pixel(canvas, 2, 1) == Canvas.pack(255, 255, 255, 255)
  end

  test "pack/4 and unpack/1 round-trip" do
    color = Canvas.pack(10, 20, 30, 255)
    assert Canvas.unpack(color) == {10, 20, 30, 255}
  end

  test "put_pixel/4 sets a single pixel, leaving others unchanged" do
    color = Canvas.pack(255, 0, 0, 255)
    canvas = Canvas.new(2, 2) |> Canvas.put_pixel(1, 0, color)

    assert Canvas.get_pixel(canvas, 1, 0) == color
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
  end

  test "put_pixel/4 out of bounds is a no-op" do
    canvas = Canvas.new(2, 2)
    result = Canvas.put_pixel(canvas, 5, 5, Canvas.pack(0, 0, 0, 255))
    assert result == canvas
  end

  test "fill_rect/6 fills exactly the given area" do
    color = Canvas.pack(0, 255, 0, 255)
    canvas = Canvas.new(4, 4) |> Canvas.fill_rect(1, 1, 2, 2, color)

    assert Canvas.get_pixel(canvas, 1, 1) == color
    assert Canvas.get_pixel(canvas, 2, 2) == color
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
    assert Canvas.get_pixel(canvas, 3, 3) == Canvas.pack(255, 255, 255, 255)
  end

  test "fill_circle/5 fills pixels within radius and leaves the far corner untouched" do
    color = Canvas.pack(0, 0, 255, 255)
    canvas = Canvas.new(10, 10) |> Canvas.fill_circle(5, 5, 3, color)

    assert Canvas.get_pixel(canvas, 5, 5) == color
    assert Canvas.get_pixel(canvas, 0, 0) == Canvas.pack(255, 255, 255, 255)
  end

  test "draw_line/7 draws a horizontal line with the given width" do
    color = Canvas.pack(0, 0, 0, 255)
    canvas = Canvas.new(10, 10) |> Canvas.draw_line(1, 5, 8, 5, color, 4)

    assert Canvas.get_pixel(canvas, 4, 5) == color
    assert Canvas.get_pixel(canvas, 4, 0) == Canvas.pack(255, 255, 255, 255)
  end

  test "downsample/2 averages each NxN block into one pixel" do
    canvas =
      Canvas.new(2, 2)
      |> Canvas.put_pixel(0, 0, Canvas.pack(0, 0, 0, 255))
      |> Canvas.put_pixel(1, 0, Canvas.pack(255, 255, 255, 255))
      |> Canvas.put_pixel(0, 1, Canvas.pack(0, 0, 0, 255))
      |> Canvas.put_pixel(1, 1, Canvas.pack(255, 255, 255, 255))

    result = Canvas.downsample(canvas, 2)

    assert result.width == 1
    assert result.height == 1
    assert Canvas.get_pixel(result, 0, 0) == Canvas.pack(128, 128, 128, 255)
  end

  test "to_scanlines/1 returns one binary per row, each width * 4 bytes" do
    canvas = Canvas.new(2, 1) |> Canvas.put_pixel(1, 0, Canvas.pack(1, 2, 3, 255))
    [scanline] = Canvas.to_scanlines(canvas)

    assert scanline == <<255, 255, 255, 255, 1, 2, 3, 255>>
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/png/canvas_test.exs`
Expected: FAIL — `Plotto.PNG.Canvas` module is undefined.

- [ ] **Step 3: Implement `Plotto.PNG.Canvas`**

```elixir
defmodule Plotto.PNG.Canvas do
  @moduledoc false

  defstruct [:width, :height, :pixels]

  # 0xFFFFFFFF = pack(255, 255, 255, 255) — inlined because a module attribute
  # cannot call a function defined in the same module (it isn't compiled yet
  # when attributes are evaluated).
  @white 0xFFFFFFFF

  def pack(r, g, b, a), do: r * 16_777_216 + g * 65_536 + b * 256 + a

  def unpack(color) do
    <<r::8, g::8, b::8, a::8>> = <<color::32>>
    {r, g, b, a}
  end

  def new(width, height) do
    %__MODULE__{width: width, height: height, pixels: :array.new(width * height, default: @white)}
  end

  def get_pixel(%__MODULE__{width: width} = canvas, x, y) do
    :array.get(y * width + x, canvas.pixels)
  end

  def put_pixel(%__MODULE__{width: width, height: height} = canvas, x, y, color)
      when x >= 0 and x < width and y >= 0 and y < height do
    %{canvas | pixels: :array.set(y * width + x, color, canvas.pixels)}
  end

  def put_pixel(canvas, _x, _y, _color), do: canvas

  def fill_rect(canvas, x, y, w, h, color) do
    x0 = round(x)
    y0 = round(y)
    x1 = round(x + w) - 1
    y1 = round(y + h) - 1

    Enum.reduce(y0..y1, canvas, fn py, canvas ->
      Enum.reduce(x0..x1, canvas, fn px, canvas -> put_pixel(canvas, px, py, color) end)
    end)
  end

  def fill_circle(canvas, cx, cy, r, color) do
    x0 = floor(cx - r)
    x1 = ceil(cx + r)
    y0 = floor(cy - r)
    y1 = ceil(cy + r)
    r_squared = r * r

    Enum.reduce(y0..y1, canvas, fn py, canvas ->
      Enum.reduce(x0..x1, canvas, fn px, canvas ->
        dx = px + 0.5 - cx
        dy = py + 0.5 - cy

        if dx * dx + dy * dy <= r_squared do
          put_pixel(canvas, px, py, color)
        else
          canvas
        end
      end)
    end)
  end

  def draw_line(canvas, x0, y0, x1, y1, color, width \\ 1) do
    half = width / 2

    if abs(x1 - x0) >= abs(y1 - y0) do
      draw_line_x_major(canvas, x0, y0, x1, y1, color, half)
    else
      draw_line_y_major(canvas, x0, y0, x1, y1, color, half)
    end
  end

  defp draw_line_x_major(canvas, x0, y0, x1, y1, color, half) do
    {x0, y0, x1, y1} = if x0 <= x1, do: {x0, y0, x1, y1}, else: {x1, y1, x0, y0}
    dx = x1 - x0
    dy = y1 - y0

    Enum.reduce(round(x0)..round(x1), canvas, fn px, canvas ->
      t = if dx == 0, do: 0, else: (px - x0) / dx
      center_y = y0 + t * dy

      Enum.reduce(round(center_y - half)..round(center_y + half), canvas, fn py, canvas ->
        put_pixel(canvas, px, py, color)
      end)
    end)
  end

  defp draw_line_y_major(canvas, x0, y0, x1, y1, color, half) do
    {x0, y0, x1, y1} = if y0 <= y1, do: {x0, y0, x1, y1}, else: {x1, y1, x0, y0}
    dx = x1 - x0
    dy = y1 - y0

    Enum.reduce(round(y0)..round(y1), canvas, fn py, canvas ->
      t = if dy == 0, do: 0, else: (py - y0) / dy
      center_x = x0 + t * dx

      Enum.reduce(round(center_x - half)..round(center_x + half), canvas, fn px, canvas ->
        put_pixel(canvas, px, py, color)
      end)
    end)
  end

  def draw_polyline(canvas, points, color, width \\ 1) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(canvas, fn [{x0, y0}, {x1, y1}], canvas ->
      draw_line(canvas, x0, y0, x1, y1, color, width)
    end)
  end

  def downsample(%__MODULE__{width: width, height: height} = canvas, factor) do
    new_width = div(width, factor)
    new_height = div(height, factor)

    pixels =
      for ny <- 0..(new_height - 1), nx <- 0..(new_width - 1), reduce: :array.new(new_width * new_height) do
        acc -> :array.set(ny * new_width + nx, average_block(canvas, nx * factor, ny * factor, factor), acc)
      end

    %__MODULE__{width: new_width, height: new_height, pixels: pixels}
  end

  defp average_block(canvas, x0, y0, factor) do
    {r, g, b, a} =
      for dy <- 0..(factor - 1), dx <- 0..(factor - 1), reduce: {0, 0, 0, 0} do
        {racc, gacc, bacc, aacc} ->
          {pr, pg, pb, pa} = unpack(get_pixel(canvas, x0 + dx, y0 + dy))
          {racc + pr, gacc + pg, bacc + pb, aacc + pa}
      end

    count = factor * factor
    pack(round(r / count), round(g / count), round(b / count), round(a / count))
  end

  def to_scanlines(%__MODULE__{width: width, height: height} = canvas) do
    for y <- 0..(height - 1) do
      for x <- 0..(width - 1), into: <<>> do
        <<get_pixel(canvas, x, y)::32>>
      end
    end
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/png/canvas_test.exs`
Expected: PASS (9 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/png/canvas.ex test/plotto/png/canvas_test.exs
git commit --no-gpg-sign -m "Add Plotto.PNG.Canvas pixel buffer and drawing primitives"
```

---

### Task 2: `Plotto.PNG.Color` — hex color parsing

**Files:**
- Create: `lib/plotto/png/color.ex`
- Test: `test/plotto/png/color_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.PNG.ColorTest do
  use ExUnit.Case, async: true

  alias Plotto.PNG.{Canvas, Color}

  test "parse/1 converts \"#RRGGBB\" into a fully-opaque packed pixel" do
    assert Color.parse("#FF0000") == {:ok, Canvas.pack(255, 0, 0, 255)}
    assert Color.parse("#00ff00") == {:ok, Canvas.pack(0, 255, 0, 255)}
    assert Color.parse("#4E79A7") == {:ok, Canvas.pack(0x4E, 0x79, 0xA7, 255)}
  end

  test "parse/1 rejects unsupported formats" do
    assert {:error, reason} = Color.parse("#FFF")
    assert reason =~ "#RRGGBB"

    assert {:error, _reason} = Color.parse("red")
    assert {:error, _reason} = Color.parse("rgb(255,0,0)")
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/png/color_test.exs`
Expected: FAIL — `Plotto.PNG.Color` module is undefined.

- [ ] **Step 3: Implement `Plotto.PNG.Color`**

```elixir
defmodule Plotto.PNG.Color do
  @moduledoc false

  alias Plotto.PNG.Canvas

  def parse(<<"#", r1, r2, g1, g2, b1, b2>>) do
    with {:ok, r} <- hex_byte(r1, r2),
         {:ok, g} <- hex_byte(g1, g2),
         {:ok, b} <- hex_byte(b1, b2) do
      {:ok, Canvas.pack(r, g, b, 255)}
    end
  end

  def parse(value) do
    {:error, "unsupported color format: #{inspect(value)}, expected \"#RRGGBB\""}
  end

  defp hex_byte(c1, c2) do
    case Integer.parse(<<c1, c2>>, 16) do
      {value, ""} -> {:ok, value}
      _ -> {:error, "invalid hex digits in color"}
    end
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/png/color_test.exs`
Expected: PASS (2 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/png/color.ex test/plotto/png/color_test.exs
git commit --no-gpg-sign -m "Add Plotto.PNG.Color hex color parsing"
```

---

### Task 3: `Plotto.PNG.Encoder` — Canvas to PNG binary

**Files:**
- Create: `lib/plotto/png/encoder.ex`
- Test: `test/plotto/png/encoder_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.PNG.EncoderTest do
  use ExUnit.Case, async: true

  alias Plotto.PNG.{Canvas, Encoder}

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  test "encode/1 produces a binary starting with the PNG signature" do
    canvas = Canvas.new(2, 2)
    png = Encoder.encode(canvas)

    assert binary_part(png, 0, 8) == @png_signature
  end

  test "encode/1's IHDR chunk reports the canvas dimensions, 8-bit RGBA" do
    canvas = Canvas.new(3, 5)
    png = Encoder.encode(canvas)

    <<@png_signature, _length::32, "IHDR", width::32, height::32, depth::8, color_type::8, _rest::binary>> = png

    assert width == 3
    assert height == 5
    assert depth == 8
    assert color_type == 6
  end

  test "encode/1's IDAT chunk decompresses back to the filtered scanline bytes" do
    color = Canvas.pack(10, 20, 30, 255)
    canvas = Canvas.new(1, 1) |> Canvas.put_pixel(0, 0, color)
    png = Encoder.encode(canvas)

    idat_data = extract_chunk(png, "IDAT")
    decompressed = :zlib.uncompress(idat_data)

    # one scanline: filter-type byte (0) + one RGBA pixel
    assert decompressed == <<0, 10, 20, 30, 255>>
  end

  test "encode/1's chunk CRCs are valid" do
    canvas = Canvas.new(2, 2)
    png = Encoder.encode(canvas)

    ihdr_type_and_data = extract_chunk_with_type(png, "IHDR")
    expected_crc = :erlang.crc32(ihdr_type_and_data)

    crc_offset = 8 + 4 + byte_size(ihdr_type_and_data)
    <<_before::binary-size(crc_offset), actual_crc::32, _rest::binary>> = png

    assert actual_crc == expected_crc
  end

  defp extract_chunk(png, type), do: extract_chunk_with_type(png, type) |> binary_part(4, byte_size(extract_chunk_with_type(png, type)) - 4)

  defp extract_chunk_with_type(png, type) do
    {offset, length} = find_chunk(png, type, 8)
    binary_part(png, offset, length + 4)
  end

  defp find_chunk(png, type, offset) do
    <<_skip::binary-size(offset), length::32, chunk_type::binary-size(4), _rest::binary>> = png

    if chunk_type == type do
      {offset + 4, length}
    else
      find_chunk(png, type, offset + 4 + 4 + length + 4)
    end
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/png/encoder_test.exs`
Expected: FAIL — `Plotto.PNG.Encoder` module is undefined.

- [ ] **Step 3: Implement `Plotto.PNG.Encoder`**

```elixir
defmodule Plotto.PNG.Encoder do
  @moduledoc false

  alias Plotto.PNG.Canvas

  @signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  def encode(%Canvas{width: width, height: height} = canvas) do
    ihdr = chunk("IHDR", <<width::32, height::32, 8::8, 6::8, 0::8, 0::8, 0::8>>)
    idat = chunk("IDAT", :zlib.compress(raw_scanlines(canvas)))
    iend = chunk("IEND", <<>>)

    @signature <> ihdr <> idat <> iend
  end

  defp raw_scanlines(canvas) do
    canvas
    |> Canvas.to_scanlines()
    |> Enum.map(fn scanline -> <<0::8, scanline::binary>> end)
    |> IO.iodata_to_binary()
  end

  defp chunk(type, data) do
    length = byte_size(data)
    type_and_data = type <> data
    crc = :erlang.crc32(type_and_data)
    <<length::32, type_and_data::binary, crc::32>>
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/png/encoder_test.exs`
Expected: PASS (4 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/png/encoder.ex test/plotto/png/encoder_test.exs
git commit --no-gpg-sign -m "Add Plotto.PNG.Encoder"
```

---

### Task 4: `Plotto.Font.TrueType` — table directory and header tables

**Files:**
- Create: `lib/plotto/font/true_type.ex`
- Test: `test/plotto/font/true_type_test.exs`

This task builds the low-level binary parsing for the tables needed before glyph outlines: the table directory, `head`, `hhea`, `maxp`, `hmtx`, and `loca`. Tasks 5 and 6 add `cmap` and `glyf` parsing to this same module.

- [ ] **Step 1: Write the failing tests**

These tests parse the real embedded font (`fonts/DejaVuSans.ttf`) — there is no synthetic fixture, since this is the only font this library ships. The expected values below were verified directly against this file.

```elixir
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
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/font/true_type_test.exs`
Expected: FAIL — `Plotto.Font.TrueType` module is undefined.

- [ ] **Step 3: Implement the table-directory and header parsing in `Plotto.Font.TrueType`**

```elixir
defmodule Plotto.Font.TrueType do
  @moduledoc false

  import Bitwise

  def parse_tables(<<_version::32, num_tables::16, _search_range::16, _entry_selector::16,
                     _range_shift::16, rest::binary>>) do
    parse_table_entries(rest, num_tables, %{})
  end

  defp parse_table_entries(_binary, 0, acc), do: acc

  defp parse_table_entries(<<tag::binary-size(4), _checksum::32, offset::32, length::32, rest::binary>>, count, acc) do
    parse_table_entries(rest, count - 1, Map.put(acc, tag, {offset, length}))
  end

  def table_data(binary, tables, tag) do
    {offset, length} = Map.fetch!(tables, tag)
    binary_part(binary, offset, length)
  end

  def parse_head(<<_major::16, _minor::16, _revision::32, _checksum_adj::32, _magic::32,
                   _flags::16, units_per_em::16, _created::64, _modified::64,
                   _x_min::16-signed, _y_min::16-signed, _x_max::16-signed, _y_max::16-signed,
                   _mac_style::16, _lowest_rec_ppem::16, _font_direction_hint::16-signed,
                   index_to_loc_format::16-signed, _glyph_data_format::16-signed>>) do
    %{units_per_em: units_per_em, index_to_loc_format: index_to_loc_format}
  end

  def parse_hhea(<<_version::32, _ascent::16-signed, _descent::16-signed, _line_gap::16-signed,
                   _advance_width_max::16, _min_lsb::16-signed, _min_rsb::16-signed,
                   _x_max_extent::16-signed, _caret_slope_rise::16-signed, _caret_slope_run::16-signed,
                   _caret_offset::16-signed, _reserved::64, _metric_format::16-signed,
                   num_of_long_hor_metrics::16>>) do
    %{num_of_long_hor_metrics: num_of_long_hor_metrics}
  end

  def parse_maxp(<<_version::32, num_glyphs::16, _rest::binary>>) do
    %{num_glyphs: num_glyphs}
  end

  def parse_loca(binary, 0, num_glyphs) do
    (for <<offset::16 <- binary>>, do: offset * 2) |> Enum.take(num_glyphs + 1)
  end

  def parse_loca(binary, 1, num_glyphs) do
    (for <<offset::32 <- binary>>, do: offset) |> Enum.take(num_glyphs + 1)
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/font/true_type_test.exs`
Expected: PASS (5 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/font/true_type.ex test/plotto/font/true_type_test.exs
git commit --no-gpg-sign -m "Add Plotto.Font.TrueType table directory and header parsing"
```

---

### Task 5: `Plotto.Font.TrueType` — `cmap` format 4 parsing

**Files:**
- Modify: `lib/plotto/font/true_type.ex`
- Modify: `test/plotto/font/true_type_test.exs`

Adds parsing of the `cmap` table (format 4 subtable — Unicode BMP code point → glyph id), the mechanism used to look up which glyph corresponds to a character like `"A"` or `"é"`.

- [ ] **Step 1: Add the failing tests**

Add this `describe` block to `test/plotto/font/true_type_test.exs`:

```elixir
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/font/true_type_test.exs`
Expected: FAIL — `TrueType.parse_cmap/1` is undefined.

- [ ] **Step 3: Add `cmap` parsing to `Plotto.Font.TrueType`**

Add these functions to `lib/plotto/font/true_type.ex` (after `parse_extra_lsbs/3`):

```elixir
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

  defp parse_cmap_encoding_records(<<platform::16, encoding::16, offset::32, rest::binary>>, count, acc) do
    parse_cmap_encoding_records(rest, count - 1, [{platform, encoding, offset} | acc])
  end

  defp parse_cmap_format4(<<4::16, _length::16, _language::16, seg_count_x2::16,
                           _search_range::16, _entry_selector::16, _range_shift::16, rest::binary>>) do
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
          glyph_id = resolve_glyph_id(code, start_code, id_delta, id_range_offset, seg_index, seg_count, glyph_id_array_binary)
          if glyph_id == 0, do: acc, else: Map.put(acc, code, glyph_id)
        end
      end)
    end)
  end

  defp resolve_glyph_id(code, _start_code, id_delta, 0, _seg_index, _seg_count, _glyph_id_array_binary) do
    rem(code + id_delta, 65536)
  end

  defp resolve_glyph_id(code, start_code, id_delta, id_range_offset, seg_index, seg_count, glyph_id_array_binary) do
    offset_in_array = id_range_offset + 2 * (code - start_code) - 2 * (seg_count - seg_index)

    case glyph_id_array_binary do
      <<_skip::binary-size(offset_in_array), glyph_index::16, _rest::binary>> when offset_in_array >= 0 ->
        if glyph_index == 0, do: 0, else: rem(glyph_index + id_delta, 65536)

      _ ->
        0
    end
  end
```

Add `import Bitwise` was already added in Task 4's module header (needed by Task 6, harmless here).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/font/true_type_test.exs`
Expected: PASS (7 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/font/true_type.ex test/plotto/font/true_type_test.exs
git commit --no-gpg-sign -m "Add Plotto.Font.TrueType cmap format 4 parsing"
```

---

### Task 6: `Plotto.Font.TrueType` — glyph outline parsing (simple + composite) and `parse!/1`

**Files:**
- Modify: `lib/plotto/font/true_type.ex`
- Modify: `test/plotto/font/true_type_test.exs`

Adds `glyf` table parsing for both simple glyphs (letters like `"A"`) and **composite** glyphs (accented letters like `"é"`, `"ñ"` — encoded in TrueType as a combination of two simple glyphs, e.g. `"e"` + an accent mark). Then adds the top-level `parse!/1` that assembles everything from Tasks 4–6 into one `%TrueType{}` struct.

**Why composite glyphs matter:** verified directly against `fonts/DejaVuSans.ttf` — `"é"` (U+00E9) has 3 contours (2 from `"e"`'s outline + 1 accent contour) and `"ñ"` (U+00F1) has 2 contours (1 from `"n"` + 1 tilde). Skipping composite-glyph support would render every accented character as blank in the PNG output.

- [ ] **Step 1: Add the failing tests**

Add this `describe` block to `test/plotto/font/true_type_test.exs`:

```elixir
  describe "glyph outline parsing" do
    setup do
      tables = TrueType.parse_tables(@font_binary)
      head = TrueType.parse_head(TrueType.table_data(@font_binary, tables, "head"))
      maxp = TrueType.parse_maxp(TrueType.table_data(@font_binary, tables, "maxp"))
      loca = TrueType.parse_loca(TrueType.table_data(@font_binary, tables, "loca"), head.index_to_loc_format, maxp.num_glyphs)
      glyf_data = TrueType.table_data(@font_binary, tables, "glyf")

      {:ok, glyf_data: glyf_data, loca: loca}
    end

    test "parse_glyph_outline/3 returns 2 contours for 'A' (glyph id 36, a simple glyph)", %{glyf_data: glyf_data, loca: loca} do
      outline = TrueType.parse_glyph_outline(glyf_data, loca, 36)
      assert length(outline) == 2
    end

    test "parse_glyph_outline/3 returns 3 contours for 'é' (glyph id 171, a composite glyph)", %{glyf_data: glyf_data, loca: loca} do
      outline = TrueType.parse_glyph_outline(glyf_data, loca, 171)
      assert length(outline) == 3
    end

    test "parse_glyph_outline/3 returns 2 contours for 'ñ' (glyph id 179, a composite glyph)", %{glyf_data: glyf_data, loca: loca} do
      outline = TrueType.parse_glyph_outline(glyf_data, loca, 179)
      assert length(outline) == 2
    end

    test "parse_glyph_outline/3 returns [] for an empty glyph (e.g. space)", %{glyf_data: glyf_data, loca: loca} do
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/font/true_type_test.exs`
Expected: FAIL — `TrueType.parse_glyph_outline/3`, `TrueType.parse!/1`, `TrueType.lookup_glyph/2` are undefined.

- [ ] **Step 3: Add glyph outline parsing and `parse!/1` to `Plotto.Font.TrueType`**

Add a struct definition near the top of the module (right after `@moduledoc false` / `import Bitwise`):

```elixir
  defstruct [:units_per_em, :glyphs, :cmap, :missing_glyph_advance]
```

Add these functions at the end of `lib/plotto/font/true_type.ex`:

```elixir
  def parse!(binary) do
    tables = parse_tables(binary)
    head = parse_head(table_data(binary, tables, "head"))
    hhea = parse_hhea(table_data(binary, tables, "hhea"))
    maxp = parse_maxp(table_data(binary, tables, "maxp"))
    loca = parse_loca(table_data(binary, tables, "loca"), head.index_to_loc_format, maxp.num_glyphs)
    glyf_data = table_data(binary, tables, "glyf")
    hmtx = parse_hmtx(table_data(binary, tables, "hmtx"), hhea.num_of_long_hor_metrics, maxp.num_glyphs)
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
    start_offset = Enum.at(loca, glyph_id)
    end_offset = Enum.at(loca, glyph_id + 1)

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
    {x_coords, rest} = parse_glyph_coords(rest, flags, 0x02, 0x10)
    {y_coords, _rest} = parse_glyph_coords(rest, flags, 0x04, 0x20)

    points =
      Enum.zip([x_coords, y_coords, flags])
      |> Enum.map(fn {x, y, flag} -> %{x: x, y: y, on_curve: (flag &&& 0x01) == 1} end)

    split_into_contours(points, end_pts)
  end

  defp parse_glyph_flags(binary, remaining, acc) when remaining <= 0, do: {Enum.reverse(acc), binary}

  defp parse_glyph_flags(<<flag::8, rest::binary>>, remaining, acc) do
    if (flag &&& 0x08) != 0 do
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

    component_outline =
      glyf_data
      |> parse_glyph_outline(loca, glyph_index)
      |> transform_contours(a, b, c, d, dx, dy)

    acc = acc ++ component_outline

    if (flags &&& 0x0020) != 0 do
      parse_components(rest, glyf_data, loca, acc)
    else
      acc
    end
  end

  defp parse_component_args(binary, flags) do
    words? = (flags &&& 0x0001) != 0
    xy_values? = (flags &&& 0x0002) != 0

    case {words?, xy_values?} do
      {true, true} -> then_binary(binary, fn <<dx::16-signed, dy::16-signed, rest::binary>> -> {dx, dy, rest} end)
      {false, true} -> then_binary(binary, fn <<dx::8-signed, dy::8-signed, rest::binary>> -> {dx, dy, rest} end)
      {true, false} -> then_binary(binary, fn <<_p1::16, _p2::16, rest::binary>> -> {0, 0, rest} end)
      {false, false} -> then_binary(binary, fn <<_p1::8, _p2::8, rest::binary>> -> {0, 0, rest} end)
    end
  end

  defp then_binary(binary, fun), do: fun.(binary)

  defp parse_component_transform(binary, flags) do
    cond do
      (flags &&& 0x0008) != 0 ->
        <<scale::16-signed, rest::binary>> = binary
        s = f2dot14(scale)
        {s, 0, 0, s, rest}

      (flags &&& 0x0040) != 0 ->
        <<x_scale::16-signed, y_scale::16-signed, rest::binary>> = binary
        {f2dot14(x_scale), 0, 0, f2dot14(y_scale), rest}

      (flags &&& 0x0080) != 0 ->
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
```

**Note on `parse_component_args/2`:** the `then_binary/2` helper exists only so each tuple-of-flags branch can pattern-match its own binary shape inside a small anonymous function — this keeps the four argument-size/type combinations (word vs. byte, xy-values vs. point-index) each in their own clear match instead of one large nested `case`/`with`. If this reads awkwardly during implementation, an equally acceptable alternative is four separate `defp parse_component_args(binary, flags)` clauses guarded by `when` on the extracted boolean flags — either is fine, just keep the four cases exhaustive.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/font/true_type_test.exs`
Expected: PASS (15 tests, 0 failures)

Note: `parse!/1` parses all 6253 glyphs in the font; this test file reads and fully parses `fonts/DejaVuSans.ttf` multiple times across its tests (once per `parse!/1` call), and each call takes roughly 1-2 seconds — so this test file alone may take several seconds to run. This is a one-time cost per test run / per compile, not a per-render cost (see Task 7, where compiling `Plotto.Font.DejaVuSans` — which embeds the parsed term as a literal — can itself take upwards of 10 seconds; this is expected and does not indicate a problem).

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/font/true_type.ex test/plotto/font/true_type_test.exs
git commit --no-gpg-sign -m "Add Plotto.Font.TrueType glyph outline parsing (simple + composite) and parse!/1"
```

---

### Task 7: `Plotto.Font.DejaVuSans` — compile-time font embedding

**Files:**
- Create: `lib/plotto/font/dejavu_sans.ex`
- Create: `fonts/LICENSE`
- Modify: `mix.exs`
- Test: `test/plotto/font/dejavu_sans_test.exs`

Wraps `Plotto.Font.TrueType.parse!/1` in a module attribute so parsing happens **once, at compile time** — the parsed representation is embedded as a literal term in the compiled `.beam`; `font/0` does no file I/O or parsing at runtime.

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Plotto.Font.DejaVuSansTest do
  use ExUnit.Case, async: true

  alias Plotto.Font.DejaVuSans

  test "font/0 returns the pre-parsed TrueType struct" do
    font = DejaVuSans.font()

    assert font.units_per_em == 2048
    assert map_size(font.glyphs) == 6253
    assert font.cmap[?A] == 36
  end

  test "font/0 does not touch the filesystem at runtime" do
    # Calling font/0 must not raise even if we can't demonstrate filesystem
    # isolation directly in ExUnit; this test documents the expectation that
    # font/0 is a plain data accessor, not an I/O call. If it were still doing
    # File.read! here, this test would still pass (the file exists during test
    # runs) — the real guarantee is structural: `@parsed` is a module attribute,
    # not a function call inside `def font`. Review the source to confirm.
    assert %Plotto.Font.TrueType{} = DejaVuSans.font()
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/plotto/font/dejavu_sans_test.exs`
Expected: FAIL — `Plotto.Font.DejaVuSans` module is undefined.

- [ ] **Step 3: Implement `Plotto.Font.DejaVuSans`**

```elixir
defmodule Plotto.Font.DejaVuSans do
  @moduledoc false

  @font_path Path.expand("../../../fonts/DejaVuSans.ttf", __DIR__)
  @external_resource @font_path
  @parsed Plotto.Font.TrueType.parse!(File.read!(@font_path))

  def font, do: @parsed
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `mix test test/plotto/font/dejavu_sans_test.exs`
Expected: PASS (2 tests, 0 failures)

Note: the first compile of this module can take upwards of 10 seconds (it parses the whole font — ~6253 glyphs — and embeds the result as a literal term). This is expected, not a hang. Subsequent compiles are skipped by Mix unless `fonts/DejaVuSans.ttf` or `lib/plotto/font/dejavu_sans.ex` changes, thanks to `@external_resource`.

- [ ] **Step 5: Add the font license file**

Create `fonts/LICENSE` containing the official DejaVu Fonts License text (a Bitstream Vera Fonts Copyright + Arev Fonts Copyright derivative — permissive, allows redistribution including in this compiled/embedded form). Source the exact license text from the font's own accompanying documentation (most DejaVu font distributions, including Homebrew's `font-dejavu` cask and the project's official releases at `dejavu-fonts.github.io`, bundle a `LICENSE` file alongside the `.ttf` files) rather than retyping it from memory — copy it verbatim to avoid transcription errors in a legal document. If no network access is available and no local copy of the license text can be found, do not fabricate it — leave a `# TODO: add DejaVu Fonts License text (see fonts/DejaVuSans.ttf provenance)` placeholder in `fonts/LICENSE`, note this gap when reporting the task back, and flag it for a human to fill in before any Hex release.

- [ ] **Step 6: Update `mix.exs` to package the `fonts/` directory**

Hex's default package file patterns (`lib`, `priv`, `mix.exs`, `README*`, etc.) do **not** include an arbitrary top-level `fonts/` directory. Since `fonts/DejaVuSans.ttf` must be present when a dependent project compiles Plotto (to satisfy `Plotto.Font.DejaVuSans`'s compile-time `File.read!/1`), it must be explicitly included in the Hex package. Add a `package/0` function to `mix.exs`:

```elixir
defmodule Plotto.MixProject do
  use Mix.Project

  def project do
    [
      app: :plotto,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      files: ~w(lib fonts mix.exs README* .formatter.exs)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
```

- [ ] **Step 7: Verify the full suite still passes and the project still compiles cleanly**

Run: `mix compile --force --warnings-as-errors && mix test`
Expected: clean compile, full suite passes.

- [ ] **Step 8: Commit**

```bash
git add lib/plotto/font/dejavu_sans.ex test/plotto/font/dejavu_sans_test.exs fonts/LICENSE mix.exs
git commit --no-gpg-sign -m "Add Plotto.Font.DejaVuSans compile-time font embedding"
```

---

### Task 8: `Plotto.Font.Glyph` — outline flattening and rasterization

**Files:**
- Create: `lib/plotto/font/glyph.ex`
- Test: `test/plotto/font/glyph_test.exs`

Converts a glyph's outline (on/off-curve points from Task 6, forming quadratic Bézier contours) into pixels drawn on a `Plotto.PNG.Canvas`, via polygon flattening + non-zero-winding scanline fill.

**Validated design:** this exact flattening/fill algorithm was hand-tested against the real embedded font by rendering the letter "A" to a 40x40 ASCII-art grid and confirming it visually reads as the letter A (a clear triangular shape with a crossbar) before being written into this plan.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.Font.GlyphTest do
  use ExUnit.Case, async: true

  alias Plotto.Font.{DejaVuSans, Glyph, TrueType}
  alias Plotto.PNG.Canvas

  test "draw/6 with an empty outline (e.g. space) leaves the canvas unchanged" do
    canvas = Canvas.new(10, 10)
    glyph = %{outline: [], advance_width: 500}

    result = Glyph.draw(canvas, glyph, 0, 0, 1.0, Canvas.pack(0, 0, 0, 255))

    assert result == canvas
  end

  test "draw/6 renders a real glyph ('A') producing a plausible bounding shape" do
    font = DejaVuSans.font()
    glyph = TrueType.lookup_glyph(font, ?A)

    # font_size 20, scaled to a small canvas: scale = font_size / units_per_em
    scale = 20 / font.units_per_em
    canvas = Canvas.new(30, 30)
    color = Canvas.pack(0, 0, 0, 255)

    result = Glyph.draw(canvas, glyph, 5, 25, scale, color)

    black_pixel_count =
      for x <- 0..29, y <- 0..29, Canvas.get_pixel(result, x, y) == color, reduce: 0 do
        acc -> acc + 1
      end

    # A 20px-tall "A" should paint a meaningful number of pixels, not zero and
    # not the entire canvas.
    assert black_pixel_count > 10
    assert black_pixel_count < 900
  end

  test "draw/6 renders a glyph with a hole (e.g. 'A') with the hole NOT filled" do
    font = DejaVuSans.font()
    glyph = TrueType.lookup_glyph(font, ?A)
    scale = 40 / font.units_per_em
    canvas = Canvas.new(60, 60)
    color = Canvas.pack(0, 0, 0, 255)

    result = Glyph.draw(canvas, glyph, 5, 55, scale, color)

    # The center of a large "A" (inside its triangular counter) should remain
    # unpainted thanks to non-zero winding across the outer+inner contours.
    assert Canvas.get_pixel(result, 30, 45) != color
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/font/glyph_test.exs`
Expected: FAIL — `Plotto.Font.Glyph` module is undefined.

- [ ] **Step 3: Implement `Plotto.Font.Glyph`**

```elixir
defmodule Plotto.Font.Glyph do
  @moduledoc false

  alias Plotto.PNG.Canvas

  def draw(canvas, %{outline: []}, _x, _y, _scale, _color), do: canvas

  def draw(canvas, %{outline: outline}, x, y, scale, color) do
    polygons =
      outline
      |> Enum.map(&flatten_contour/1)
      |> Enum.reject(&(&1 == []))
      |> Enum.map(fn contour ->
        Enum.map(contour, fn {gx, gy} -> {x + gx * scale, y - gy * scale} end)
      end)

    case bounding_box(polygons) do
      :empty ->
        canvas

      {min_x, max_x, min_y, max_y} ->
        Enum.reduce(round(min_y)..round(max_y), canvas, fn py, canvas ->
          Enum.reduce(round(min_x)..round(max_x), canvas, fn px, canvas ->
            if inside?(polygons, px + 0.5, py + 0.5) do
              Canvas.put_pixel(canvas, px, py, color)
            else
              canvas
            end
          end)
        end)
    end
  end

  defp bounding_box([]), do: :empty

  defp bounding_box(polygons) do
    points = List.flatten(polygons)
    xs = Enum.map(points, &elem(&1, 0))
    ys = Enum.map(points, &elem(&1, 1))
    {Enum.min(xs), Enum.max(xs), Enum.min(ys), Enum.max(ys)}
  end

  defp inside?(polygons, px, py) do
    Enum.reduce(polygons, 0, fn poly, acc -> acc + winding_number(poly, px, py) end) != 0
  end

  defp winding_number(poly, px, py) do
    edges = Enum.zip(poly, tl(poly) ++ [hd(poly)])

    Enum.reduce(edges, 0, fn {{x1, y1}, {x2, y2}}, acc ->
      cond do
        y1 <= py and y2 > py and is_left(x1, y1, x2, y2, px, py) > 0 -> acc + 1
        y1 > py and y2 <= py and is_left(x1, y1, x2, y2, px, py) < 0 -> acc - 1
        true -> acc
      end
    end)
  end

  defp is_left(x1, y1, x2, y2, px, py), do: (x2 - x1) * (py - y1) - (px - x1) * (y2 - y1)

  def flatten_contour(points) do
    points = ensure_starts_on_curve(points)
    closed = points ++ [List.first(points)]
    expand_implied_points(closed) |> build_segments()
  end

  defp ensure_starts_on_curve(points) do
    case Enum.find_index(points, & &1.on_curve) do
      0 ->
        points

      nil ->
        [p0 | _] = points
        last = List.last(points)
        [midpoint(last, p0) | points]

      idx ->
        {before, at_and_after} = Enum.split(points, idx)
        at_and_after ++ before
    end
  end

  defp midpoint(a, b), do: %{x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, on_curve: true}

  defp expand_implied_points([single]), do: [single]

  defp expand_implied_points([p1, p2 | rest]) do
    if not p1.on_curve and not p2.on_curve do
      [p1, midpoint(p1, p2) | expand_implied_points([p2 | rest])]
    else
      [p1 | expand_implied_points([p2 | rest])]
    end
  end

  defp build_segments([]), do: []
  defp build_segments([_last]), do: []

  defp build_segments([p1, p2]) when p1.on_curve and p2.on_curve do
    [{p1.x, p1.y}, {p2.x, p2.y}]
  end

  defp build_segments([p1, p2, p3 | rest]) when p1.on_curve and p2.on_curve do
    [{p1.x, p1.y} | build_segments([p2, p3 | rest])]
  end

  defp build_segments([p1, p2, p3 | rest]) when p1.on_curve and not p2.on_curve and p3.on_curve do
    flatten_quad_bezier(p1, p2, p3, 8) ++ build_segments([p3 | rest])
  end

  defp flatten_quad_bezier(p0, p1, p2, steps) do
    for i <- 0..(steps - 1) do
      t = i / steps
      mt = 1 - t
      x = mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x
      y = mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
      {x, y}
    end
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/font/glyph_test.exs`
Expected: PASS (3 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/font/glyph.ex test/plotto/font/glyph_test.exs
git commit --no-gpg-sign -m "Add Plotto.Font.Glyph outline flattening and rasterization"
```

---

### Task 9: `Plotto.PNG.Rasterizer` — shapes

**Files:**
- Create: `lib/plotto/png/rasterizer.ex`
- Test: `test/plotto/png/rasterizer_test.exs`

Walks the existing `Plotto.SVG.Element` tree (unchanged, reused from the SVG pipeline) and draws `<rect>`, `<line>`, `<polyline>`, and `<circle>` onto a `Plotto.PNG.Canvas` sized at 4x the final resolution. Text (`<text>`) is handled in Task 10.

**Coordinate scaling reminder (from the spec):** every position/size value read from the element tree is in final (1x) pixel units — this task must multiply each one by the supersampling factor (4) before drawing.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.PNG.RasterizerTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.Element
  alias Plotto.PNG.{Canvas, Rasterizer}

  test "supersample_factor/0 is 4" do
    assert Rasterizer.supersample_factor() == 4
  end

  test "rasterize/3 creates a canvas at 4x the given width/height" do
    tree = Element.new("svg", %{}, [])
    canvas = Rasterizer.rasterize(tree, 10, 8)

    assert canvas.width == 40
    assert canvas.height == 32
  end

  test "a <rect> is scaled by 4x and filled with its color" do
    rect = Element.new("rect", %{x: 1, y: 1, width: 2, height: 2, fill: "#FF0000"})
    tree = Element.new("svg", %{}, [rect])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(255, 0, 0, 255)

    # rect spans x:[1,3) y:[1,3) in 1x units -> x:[4,12) y:[4,12) at 4x
    assert Canvas.get_pixel(canvas, 5, 5) == color
    assert Canvas.get_pixel(canvas, 0, 0) != color
  end

  test "a <circle> is scaled by 4x and filled with its color" do
    circle = Element.new("circle", %{cx: 5, cy: 5, r: 2, fill: "#00FF00"})
    tree = Element.new("svg", %{}, [circle])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(0, 255, 0, 255)

    assert Canvas.get_pixel(canvas, 20, 20) == color
  end

  test "a <line> is scaled by 4x and drawn with its stroke color" do
    line = Element.new("line", %{x1: 0, y1: 5, x2: 9, y2: 5, stroke: "#0000FF"})
    tree = Element.new("svg", %{}, [line])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(0, 0, 255, 255)

    assert Canvas.get_pixel(canvas, 20, 20) == color
  end

  test "a <polyline> is scaled by 4x and drawn with its stroke color" do
    polyline = Element.new("polyline", %{points: "0,5 9,5", fill: "none", stroke: "#0000FF"})
    tree = Element.new("svg", %{}, [polyline])

    canvas = Rasterizer.rasterize(tree, 10, 10)
    color = Canvas.pack(0, 0, 255, 255)

    assert Canvas.get_pixel(canvas, 20, 20) == color
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/png/rasterizer_test.exs`
Expected: FAIL — `Plotto.PNG.Rasterizer` module is undefined.

- [ ] **Step 3: Implement shape handling in `Plotto.PNG.Rasterizer`**

```elixir
defmodule Plotto.PNG.Rasterizer do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.PNG.{Canvas, Color}

  @supersample 4

  def supersample_factor, do: @supersample

  def rasterize(%Element{} = root, width, height) do
    canvas = Canvas.new(width * @supersample, height * @supersample)
    draw_element(canvas, root)
  end

  defp draw_element(canvas, %Element{tag: "svg", children: children}) do
    Enum.reduce(children, canvas, fn child, canvas -> draw_element(canvas, child) end)
  end

  defp draw_element(canvas, %Element{tag: "g", children: children}) do
    Enum.reduce(children, canvas, fn child, canvas -> draw_element(canvas, child) end)
  end

  defp draw_element(canvas, %Element{tag: "rect", attrs: attrs}) do
    x = num(attrs["x"]) * @supersample
    y = num(attrs["y"]) * @supersample
    w = num(attrs["width"]) * @supersample
    h = num(attrs["height"]) * @supersample
    {:ok, color} = Color.parse(attrs["fill"])

    Canvas.fill_rect(canvas, x, y, w, h, color)
  end

  defp draw_element(canvas, %Element{tag: "circle", attrs: attrs}) do
    cx = num(attrs["cx"]) * @supersample
    cy = num(attrs["cy"]) * @supersample
    r = num(attrs["r"]) * @supersample
    {:ok, color} = Color.parse(attrs["fill"])

    Canvas.fill_circle(canvas, cx, cy, r, color)
  end

  defp draw_element(canvas, %Element{tag: "line", attrs: attrs}) do
    x1 = num(attrs["x1"]) * @supersample
    y1 = num(attrs["y1"]) * @supersample
    x2 = num(attrs["x2"]) * @supersample
    y2 = num(attrs["y2"]) * @supersample
    {:ok, color} = Color.parse(attrs["stroke"])
    width = num(Map.get(attrs, "stroke-width", "1")) * @supersample

    Canvas.draw_line(canvas, x1, y1, x2, y2, color, width)
  end

  defp draw_element(canvas, %Element{tag: "polyline", attrs: attrs}) do
    points =
      attrs["points"]
      |> String.split(" ")
      |> Enum.map(fn pair ->
        [x, y] = String.split(pair, ",")
        {num(x) * @supersample, num(y) * @supersample}
      end)

    {:ok, color} = Color.parse(attrs["stroke"])
    width = num(Map.get(attrs, "stroke-width", "1")) * @supersample

    Canvas.draw_polyline(canvas, points, color, width)
  end

  defp draw_element(canvas, %Element{tag: "text"}), do: canvas

  defp num(str), do: elem(Float.parse(str), 0)
end
```

(The `"text"` clause is a placeholder returning the canvas unchanged — Task 10 replaces it with real text rendering.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/png/rasterizer_test.exs`
Expected: PASS (6 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/png/rasterizer.ex test/plotto/png/rasterizer_test.exs
git commit --no-gpg-sign -m "Add Plotto.PNG.Rasterizer shape handling"
```

---

### Task 10: `Plotto.PNG.Rasterizer` — text

**Files:**
- Modify: `lib/plotto/png/rasterizer.ex`
- Modify: `test/plotto/png/rasterizer_test.exs`

Replaces the Task 9 placeholder `<text>` clause with real glyph rendering: font-size scaling (design units → pixels → 4x supersampled subpixels), `text-anchor` alignment, missing-glyph fallback, and per-character advance.

- [ ] **Step 1: Add the failing tests**

Add to `test/plotto/png/rasterizer_test.exs`:

```elixir
  describe "text rendering" do
    test "a <text> with text-anchor=\"start\" paints pixels near its x,y" do
      text = Element.new("text", %{x: 5, y: 20, "font-size": 12, "text-anchor": "start", fill: "#000000"}, ["A"])
      tree = Element.new("svg", %{}, [text])

      canvas = Rasterizer.rasterize(tree, 40, 40)
      color = Canvas.pack(0, 0, 0, 255)

      painted? =
        for x <- 0..159, y <- 0..159, reduce: false do
          acc -> acc or Canvas.get_pixel(canvas, x, y) == color
        end

      assert painted?
    end

    test "a <text> with an unsupported codepoint does not crash and still advances" do
      # U+1F600 (an emoji) is not in DejaVu Sans's cmap; this should render the
      # rest of the string without raising.
      text = Element.new("text", %{x: 5, y: 20, "font-size": 12, fill: "#000000"}, [<<0x1F600::utf8>> <> "A"])
      tree = Element.new("svg", %{}, [text])

      assert %Plotto.PNG.Canvas{} = Rasterizer.rasterize(tree, 40, 40)
    end

    test "text-anchor=\"middle\" centers the text around x, differing from \"start\"" do
      start_text = Element.new("text", %{x: 20, y: 20, "font-size": 12, "text-anchor": "start", fill: "#000000"}, ["AAAA"])
      middle_text = Element.new("text", %{x: 20, y: 20, "font-size": 12, "text-anchor": "middle", fill: "#000000"}, ["AAAA"])

      start_canvas = Rasterizer.rasterize(Element.new("svg", %{}, [start_text]), 40, 40)
      middle_canvas = Rasterizer.rasterize(Element.new("svg", %{}, [middle_text]), 40, 40)

      refute start_canvas == middle_canvas
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/png/rasterizer_test.exs`
Expected: FAIL — the placeholder `<text>` clause paints nothing, so the "painted?" assertion fails; the two canvases in the anchor test come out equal (both blank).

- [ ] **Step 3: Replace the `<text>` placeholder with real rendering**

In `lib/plotto/png/rasterizer.ex`, replace:

```elixir
  defp draw_element(canvas, %Element{tag: "text"}), do: canvas
```

with:

```elixir
  defp draw_element(canvas, %Element{tag: "text", attrs: attrs, children: [text]}) do
    font = DejaVuSans.font()
    font_size = num(attrs["font-size"])
    scale = font_size / font.units_per_em * @supersample
    {:ok, color} = Color.parse(attrs["fill"])

    glyphs =
      text
      |> String.to_charlist()
      |> Enum.map(fn codepoint ->
        TrueType.lookup_glyph(font, codepoint) || %{outline: [], advance_width: font.missing_glyph_advance}
      end)

    total_width = glyphs |> Enum.map(& &1.advance_width) |> Enum.sum() |> Kernel.*(scale)
    anchored_x = num(attrs["x"]) * @supersample

    start_x =
      case attrs["text-anchor"] do
        "middle" -> anchored_x - total_width / 2
        "end" -> anchored_x - total_width
        _ -> anchored_x
      end

    y = num(attrs["y"]) * @supersample

    {canvas, _final_x} =
      Enum.reduce(glyphs, {canvas, start_x}, fn glyph, {canvas, x} ->
        canvas = Glyph.draw(canvas, glyph, x, y, scale, color)
        {canvas, x + glyph.advance_width * scale}
      end)

    canvas
  end
```

And add these aliases near the top of the module (alongside the existing `alias Plotto.PNG.{Canvas, Color}`):

```elixir
  alias Plotto.Font.{DejaVuSans, Glyph, TrueType}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/png/rasterizer_test.exs`
Expected: PASS (9 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/png/rasterizer.ex test/plotto/png/rasterizer_test.exs
git commit --no-gpg-sign -m "Add text rendering to Plotto.PNG.Rasterizer"
```

---

### Task 11: `Plotto` public API — `to_png/1` and `to_png!/1`

**Files:**
- Modify: `lib/plotto.ex`
- Modify: `test/plotto_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto_test.exs`:

```elixir
  describe "to_png/1 and to_png!/1" do
    @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

    test "to_png/1 returns {:ok, png_binary} for a bar chart, at final (non-supersampled) dimensions" do
      chart = BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}], width: 100, height: 80)
      assert {:ok, png} = Plotto.to_png(chart)

      assert binary_part(png, 0, 8) == @png_signature
      <<@png_signature, _length::32, "IHDR", width::32, height::32, _rest::binary>> = png
      assert width == 100
      assert height == 80
    end

    test "to_png!/1 returns the png binary directly for a line chart" do
      chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
      png = Plotto.to_png!(chart)

      assert binary_part(png, 0, 8) == @png_signature
    end

    test "to_png/1 returns {:error, reason} for a value that isn't a supported chart" do
      assert {:error, reason} = Plotto.to_png(%{not: "a chart"})
      assert is_binary(reason)
    end

    test "to_png!/1 raises ArgumentError for a value that isn't a supported chart" do
      assert_raise ArgumentError, fn -> Plotto.to_png!(%{not: "a chart"}) end
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto_test.exs`
Expected: FAIL — `Plotto.to_png/1` is undefined.

- [ ] **Step 3: Implement `to_png/1` and `to_png!/1`**

In `lib/plotto.ex`, add these aliases and functions alongside the existing `to_svg/1`/`to_svg!/1`:

```elixir
  alias Plotto.PNG.{Canvas, Encoder, Rasterizer}
```

```elixir
  @doc """
  Renders a chart (`Plotto.BarChart` or `Plotto.LineChart`) to a PNG binary.

  Returns `{:ok, png}` on success or `{:error, reason}` if rendering fails.
  """
  @spec to_png(struct()) :: {:ok, binary()} | {:error, String.t()}
  def to_png(chart) do
    %{width: width, height: height} = chart.opts

    png =
      chart
      |> Renderer.render()
      |> Rasterizer.rasterize(width, height)
      |> Canvas.downsample(Rasterizer.supersample_factor())
      |> Encoder.encode()

    {:ok, png}
  rescue
    error -> {:error, Exception.message(error)}
  end

  @doc "Same as `to_png/1`, but returns the PNG binary directly and raises on failure."
  @spec to_png!(struct()) :: binary()
  def to_png!(chart) do
    case to_png(chart) do
      {:ok, png} -> png
      {:error, reason} -> raise ArgumentError, reason
    end
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test`
Expected: PASS (entire suite, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto.ex test/plotto_test.exs
git commit --no-gpg-sign -m "Add Plotto.to_png/1 and to_png!/1 public API"
```

---

### Task 12: End-to-end integration and visual sanity check

**Files:**
- Modify: `test/plotto_test.exs`

Adds a couple of broader integration tests, then a manual visual check (not an automated test) to confirm the whole pipeline actually looks right — mirroring the manual PNG verification already done while designing this plan.

- [ ] **Step 1: Add integration tests**

Add to `test/plotto_test.exs`:

```elixir
  describe "to_png!/1 end-to-end" do
    test "a bar chart with a title, custom colors, and 3+ items renders without error" do
      data = [
        %{label: "Jan", value: 10},
        %{label: "Feb", value: 25},
        %{label: "Mar", value: 18},
        %{label: "Apr", value: 30}
      ]

      chart = BarChart.new!(data, title: "Sales", colors: ["#4E79A7", "#F28E2B"])
      png = Plotto.to_png!(chart)

      assert byte_size(png) > 0
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a chart with a label containing accented characters renders without error" do
      data = [%{label: "Niño", value: 10}, %{label: "café", value: 15}]
      chart = BarChart.new!(data, title: "Tendencias")

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end
  end
```

- [ ] **Step 2: Run the tests to verify they pass**

Run: `mix test`
Expected: PASS (entire suite, 0 failures)

- [ ] **Step 3: Manual visual check**

Run this in `iex -S mix` (or a throwaway `.exs` script) and open the resulting file to confirm it looks like an actual, readable bar chart with visible title/axis text — not just a technically-valid-but-garbled PNG:

```elixir
data = [
  %{label: "Ene", value: 42},
  %{label: "Feb", value: 58},
  %{label: "Mar", value: 33},
  %{label: "Abr", value: 71}
]

chart = Plotto.BarChart.new!(data, title: "Ventas")
File.write!("/tmp/plotto_check.png", Plotto.to_png!(chart))
```

Open `/tmp/plotto_check.png` and confirm: four bars of increasing/decreasing height matching the data, a title reading "Ventas", x-axis labels "Ene"/"Feb"/"Mar"/"Abr", y-axis tick labels, and no visibly broken/garbled text. If text looks wrong (e.g. glyphs overlapping, wrong vertical position), re-check the `font-size`/`text-anchor` scaling math in Task 10 against the spec's "Text layout and stroke width in the Rasterizer" section before proceeding.

- [ ] **Step 4: Commit**

```bash
git add test/plotto_test.exs
git commit --no-gpg-sign -m "Add end-to-end PNG integration tests"
```

---

## Definition of done

- `mix test` passes with 0 failures.
- `mix format --check-formatted` passes.
- `mix compile --warnings-as-errors` is clean.
- `Plotto.BarChart.new!(data, opts) |> Plotto.to_png!/1` and the equivalent for `Plotto.LineChart` produce a valid PNG at the chart's configured (non-supersampled) width/height, with visible bars/line, axis labels, and title text, confirmed by the Task 12 manual check.
- Labels containing accented Latin characters (á, é, í, ó, ú, ñ, ü) render correctly, not blank.
- No new Hex dependencies were added to `mix.exs`.
- `fonts/DejaVuSans.ttf` is NOT part of `priv/` and is not read at runtime — confirmed by `Plotto.Font.DejaVuSans`'s implementation using a module attribute, not a runtime `File.read!/1`.
