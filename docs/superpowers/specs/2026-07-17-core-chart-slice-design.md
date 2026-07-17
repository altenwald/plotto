# Plotto — Core Chart Slice (Bar & Line, SVG + PNG)

**Status:** Draft
**Date:** 2026-07-17

## Summary

Plotto is a 100% Elixir charting library that generates SVG charts and can
export the same chart to PNG. This spec covers the first vertical slice:
two chart types (bar and line), the SVG rendering pipeline, a pure-Elixir
PNG export pipeline (including a TrueType font parser and rasterizer), and
the public API. Additional chart types are out of scope and will get their
own specs once this slice is validated.

## Goals

- Build a bar chart and a line chart end to end: data in, SVG string and
  PNG binary out.
- Allow arbitrary HTML/SVG attributes (e.g. `phx-click`, `data-*`) to be
  attached to individual data points, without Plotto depending on Phoenix
  or LiveView in any way.
- Export to PNG using only Elixir/Erlang standard capabilities (no shelling
  out to external binaries, no NIFs). This includes rasterizing shapes and
  rendering text from a TrueType font.
- Keep the SVG and PNG outputs backed by the same layout computation, so
  the two formats never drift apart.

## Non-goals (for this slice)

- Chart types other than bar and line (pie, scatter, area, etc.).
- OpenType/CFF font support — only TrueType (`.ttf`, `glyf` table).
- A theming system beyond a small set of basic options (colors, size,
  title).
- Any Phoenix/LiveView integration code or dependency.
- Multi-series line charts. `Plotto.LineChart` renders a single line in
  this slice; a `:series`/grouping key on data items is future work.
- Numeric or time-based X axes. Both chart types use a categorical X axis
  driven by `:label` (see "SVG rendering" below).

## Architecture

```
Plotto                      # public API: to_svg/1, to_svg!/1, to_png/1, to_png!/1
Plotto.BarChart              # struct + new/2, new!/2
Plotto.LineChart             # struct + new/2, new!/2
Plotto.Axis                  # scale (linear/categorical) and tick computation, shared
Plotto.Theme                 # default colors/sizes + basic options

Plotto.SVG.Element           # generic node {tag, attrs, children} — intermediate tree
Plotto.SVG.Renderer          # BarChart/LineChart -> Plotto.SVG.Element tree
Plotto.SVG.Serializer        # tree -> String.t() (XML)

Plotto.PNG.Rasterizer        # Plotto.SVG.Element tree -> Plotto.PNG.Canvas
Plotto.PNG.Canvas            # RGBA pixel buffer + primitives (fill_rect, line, circle)
Plotto.PNG.Encoder           # Canvas -> PNG binary (uses :zlib for DEFLATE compression)
Plotto.Font.TrueType         # .ttf table parser (head, maxp, loca, glyf, cmap, hmtx)
Plotto.Font.Glyph            # glyph outline (lines/quadratic beziers) -> rasterized coverage
```

### Data flow

1. The caller builds a `BarChart` or `LineChart` struct via `new/2` /
   `new!/2`, which validates the input data.
2. `Plotto.SVG.Renderer` turns the chart struct into an intermediate
   `Plotto.SVG.Element` tree, using `Plotto.Axis` for scales/ticks and
   `Plotto.Theme` for default styling.
3. This **same tree** feeds two independent consumers:
   - `Plotto.SVG.Serializer` walks it into an SVG XML string.
   - `Plotto.PNG.Rasterizer` walks it and draws onto a `Plotto.PNG.Canvas`,
     which `Plotto.PNG.Encoder` then serializes into a PNG binary.

Because both output formats are derived from the same tree, layout logic
(bar positions, axis ticks, point coordinates) is computed exactly once.

## Public API

```elixir
data = [
  %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
  %{label: "Feb", value: 25}
]

{:ok, chart} = Plotto.BarChart.new(data, title: "Sales", width: 600, height: 400)
chart = Plotto.BarChart.new!(data, title: "Sales")

{:ok, svg} = Plotto.to_svg(chart)
svg = Plotto.to_svg!(chart)

{:ok, png_binary} = Plotto.to_png(chart)
png_binary = Plotto.to_png!(chart)
```

`Plotto.LineChart` mirrors the same shape (`new/2`, `new!/2`) and shares
`Plotto.Axis` and `Plotto.Theme` with `Plotto.BarChart`.

### Data item shape

Each data point is a map with:

- `:label` (required) — string, used as the categorical axis label (bar
  chart) or point label (line chart).
- `:value` (required) — number.
- `:attrs` (optional) — a map of string attribute name/value pairs copied
  verbatim onto the corresponding SVG element (`<rect>` for bars, `<circle>`
  for line-chart points). Plotto does not interpret these attributes in any
  way; it exists purely so a caller using Phoenix LiveView can attach
  `phx-click`, `phx-value-*`, `data-*`, etc. Plotto has no dependency on
  Phoenix or LiveView.

### Options

Basic keyword options accepted by `new/2` / `new!/2`:

- `:width`, `:height` — chart dimensions in pixels (defaults provided).
- `:title` — optional chart title text.
- `:colors` — list of colors. For `BarChart`, cycled one color per bar.
  For `LineChart`, only the first color is used, as the stroke color of
  the single line (see "Non-goals"). Default palette provided by
  `Plotto.Theme` if omitted.

### Validation and error handling

- `new/2` validates the input (non-empty list, `:label` present, `:value`
  numeric) and returns `{:ok, chart} | {:error, reason}`.
- `new!/2` performs the same validation and raises `ArgumentError` with the
  `reason` message on failure.
- `to_svg/1` and `to_png/1` return `{:ok, result} | {:error, reason}`;
  `to_svg!/1` and `to_png!/1` raise on failure. Since the chart struct was
  already validated at construction time, failures here are expected to be
  exceptional (e.g. an internal rasterizer/font limitation), not ordinary
  user input errors.

## SVG rendering

`Plotto.SVG.Renderer` builds the intermediate tree per chart type:

- **BarChart**: categorical scale on X (one band per `label`), linear scale
  on Y (`0..max(value)`, with margin). Each bar is a `<rect>` with `fill`
  from `Plotto.Theme`, plus the data item's `:attrs` if present. Negative
  `:value` inputs are out of scope for this slice — bars below a baseline
  are not supported; `new/2`/`new!/2` treat a negative `:value` as invalid
  input.
- **LineChart**: categorical scale on X (points evenly spaced by index/
  `label`, like the bar chart but without banding), linear scale on Y. The
  line is drawn as a `<polyline>`; each data point additionally gets a
  `<circle>` so per-point `:attrs` can be attached (a `<polyline>` cannot
  carry per-point attributes).
- Shared elements: an axis `<g>` (tick lines + `<text>` labels), a title
  `<text>`, and a root `<svg>` with `viewBox`, `width`, `height`.
- Text alignment (e.g. a centered `:title`) is expressed via the standard
  SVG `text-anchor` attribute on `<text>` nodes. The PNG rasterizer honors
  the same attribute by computing total glyph advance width up front (via
  `Plotto.Font.TrueType` metrics) and offsetting the draw origin
  accordingly, so SVG and PNG text alignment match.

`Plotto.SVG.Serializer` walks the tree and produces the XML string,
escaping attribute values and text content to avoid SVG/HTML injection
from user-supplied `label`/`attrs` values.

## PNG export pipeline

Reuses the same `Plotto.SVG.Element` tree as the SVG output — no layout is
recomputed.

1. **`Plotto.PNG.Rasterizer`** walks the tree and draws onto a
   `Plotto.PNG.Canvas` (an RGBA pixel buffer):
   - `<rect>` → filled area, with anti-aliased edges.
   - `<line>` / `<polyline>` → anti-aliased line drawing (Xiaolin Wu style).
   - `<circle>` → filled disc with a smoothed edge.
   - `<text>` → delegates to `Plotto.Font.TrueType`.
2. **`Plotto.Font.TrueType`** parses a `.ttf` font embedded as a default
   asset (a permissively-licensed free font, to be selected during
   implementation), reading the `cmap` (Unicode → glyph id), `glyf`/`loca`
   (per-glyph outlines), and `hmtx` (horizontal advance metrics) tables.
   Only TrueType outlines (quadratic Bézier curves) are supported —
   OpenType/CFF fonts are out of scope for this slice.
3. **`Plotto.Font.Glyph`** converts a glyph outline (line segments and
   quadratic Béziers from `glyf`) into a rasterized coverage mask
   (scanline fill, non-zero winding rule), composited onto the `Canvas`
   with the text color.
4. **`Plotto.PNG.Encoder`** serializes the `Canvas` into a PNG binary:
   signature, `IHDR` chunk, `IDAT` chunk (per-scanline filtering plus
   `:zlib.compress/1` for DEFLATE — a native Erlang module, no external
   dependency), `IEND` chunk.

## Testing strategy

- **Unit**: `BarChart.new/2` / `LineChart.new/2` validation (valid and
  invalid inputs); `Plotto.Axis` scale/tick computation; `Plotto.SVG.Element`
  construction and serialization (assertions on the resulting XML string).
- **`Plotto.Font.TrueType`**: parsing against a small fixture `.ttf`,
  verifying table contents and the outline of a known glyph.
- **`Plotto.PNG.Canvas` / `Rasterizer`**: pixel-level assertions (e.g. "the
  pixel at (10,10) after `fill_rect` has the expected color").
- **`Plotto.PNG.Encoder`**: round-trip test — generate a PNG and verify a
  valid signature/header, and that `:zlib.uncompress/1` on the `IDAT` chunk
  reconstructs the expected pixel data (no external PNG decoder dependency).
- **Integration**: `Plotto.to_png!/1` on a sample `BarChart`/`LineChart`
  produces a binary with a valid PNG signature and correct dimensions.

## Open questions for the implementation plan

- Which specific `.ttf` font to embed as the default (must be
  permissively licensed and redistributable).
- Default color palette values in `Plotto.Theme`.
- Exact anti-aliasing technique/quality trade-off for the rasterizer.
- Default `:width`/`:height` pixel values.
