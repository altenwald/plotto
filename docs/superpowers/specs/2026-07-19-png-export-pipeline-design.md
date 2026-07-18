# Plotto — PNG Export Pipeline (100% Elixir)

**Status:** Draft
**Date:** 2026-07-19

## Summary

This spec covers exporting a Plotto chart to a PNG binary, using only
Elixir/Erlang standard capabilities — no shelling out to external binaries
(`rsvg-convert`, ImageMagick, etc.), no NIFs, no Rust. This includes a
TrueType font parser, a glyph rasterizer, a shape rasterizer, and a PNG
encoder. It builds directly on the SVG core pipeline
(`docs/superpowers/specs/2026-07-17-core-chart-slice-design.md` and its
implementation, `docs/superpowers/plans/2026-07-18-svg-core-pipeline.md`),
reusing `Plotto.SVG.Renderer`'s output tree so PNG and SVG never drift
apart on layout.

## Goals

- `Plotto.to_png/1` / `Plotto.to_png!/1`: render any `Plotto.BarChart` or
  `Plotto.LineChart` to a valid PNG binary, matching the SVG output's
  layout (same axis positions, bar/point positions, title).
- Render text (axis labels, tick labels, title) in the PNG using an
  embedded TrueType font — not just shapes.
- Anti-aliased output (via supersampling, see below) so the PNG doesn't
  look visibly worse than the SVG rendered in a browser.
- Support the full character set the embedded font provides (this is a
  general-purpose library — not just ASCII/Spanish labels), since parsing
  the whole font costs the same memory whether done once at compile time
  or cached at runtime.

## Non-goals (for this slice)

- OpenType/CFF font support — TrueType (`glyf` outlines) only, as already
  established in the core spec.
- Kerning, ligatures, color/emoji glyph tables.
- Runtime-swappable/custom fonts — only the one embedded default font
  (DejaVu Sans) is supported. A public API for supplying a different font
  is future work.
- Advanced PNG compression (per-scanline Paeth/Sub/Up filtering) — v1 uses
  filter type `None` for every scanline. Revisit if output file size
  becomes a real complaint.
- Analytic-coverage anti-aliasing (à la FreeType/stb_truetype) — v1 uses
  supersampling instead (see below).

## Architecture

```
Plotto.PNG.Canvas            # RGBA pixel buffer (Erlang :array) + primitives
Plotto.PNG.Rasterizer        # Plotto.SVG.Element tree -> draws onto Canvas
Plotto.PNG.Encoder           # Canvas -> PNG binary
Plotto.Font.TrueType         # .ttf table parser (cmap, glyf, loca, hmtx, head, maxp)
Plotto.Font.Glyph            # glyph outline -> rasterized coverage, drawn onto Canvas
Plotto.Font.DejaVuSans       # compile-time-parsed embedded font data
```

### Data flow

1. `Plotto.SVG.Renderer.render/1` (already implemented) turns the chart
   struct into a `Plotto.SVG.Element` tree — unchanged, reused as-is.
2. `Plotto.PNG.Rasterizer.rasterize/3` walks that same tree and draws onto
   a `Plotto.PNG.Canvas` sized at **4x** the chart's final `width`/`height`
   (supersampling — see below), using `Plotto.Font.DejaVuSans.font/0` for
   any `<text>` node.
3. `Plotto.PNG.Canvas.downsample/1` reduces the 4x canvas to the final
   resolution, averaging each 4x4 pixel block — this is what produces
   anti-aliased edges, both for shapes and for glyph outlines.
4. `Plotto.PNG.Encoder.encode/1` serializes the final-resolution `Canvas`
   into a PNG binary.
5. `Plotto.to_png/1` / `to_png!/1` (mirroring `to_svg`/`to_svg!`) wire
   steps 1–4 together, with the same `{:ok, _} | {:error, _}` /
   raising-variant contract as the SVG API.

## Canvas and supersampling

- `Plotto.PNG.Canvas` wraps Erlang's `:array` module: an RGBA pixel buffer
  indexed by `y * width + x`, each pixel a packed `0xRRGGBBAA` integer.
  `:array` gives efficient indexed updates (structural sharing) instead of
  copying the whole buffer per draw call, and gives O(1) reads.
- The canvas starts filled with opaque white (`0xFFFFFFFF`) — charts need
  an explicit background since (unlike SVG in a browser) a PNG has no page
  behind it.
- **Supersampling factor: 4x.** All drawing (`Plotto.PNG.Rasterizer` and
  `Plotto.Font.Glyph`) happens at 4x the final pixel dimensions, using
  "hard" (non-anti-aliased) fills — a filled rectangle, line, circle, or
  glyph coverage mask is drawn with a simple in/out test per pixel, no
  per-primitive AA logic. `Canvas.downsample/1` then averages each 4x4
  block of pixels (per RGBA channel, rounded to nearest integer) into one
  final pixel. This is what supplies anti-aliasing, uniformly, for every
  primitive type, without needing separate AA code for lines vs. circles
  vs. glyphs.

## Font handling

- **DejaVu Sans** (`.ttf`, Bitstream Vera-derived license, redistributable)
  ships as `fonts/DejaVuSans.ttf` at the project root — **not** under
  `priv/`. `priv/` is for assets read at runtime by a compiled release;
  since the font is parsed once at compile time and only the resulting
  literal term is embedded in the `.beam` (see below), the raw `.ttf` is
  a compile-time-only input, never read at runtime. It must still be
  included in the Hex package tarball (so `mix deps.get` + compiling
  Plotto as a dependency has access to it) via `mix.exs`'s
  `package: [files: ...]` configuration, since Hex's default file
  patterns don't include an arbitrary top-level `fonts/` directory.
- `Plotto.Font.TrueType.parse!/1` is a normal, independently testable
  module: parses `head`/`maxp` (headers), `cmap` subtable format 4
  (Unicode BMP code point → glyph id), `glyf`/`loca` (per-glyph outlines:
  line segments and quadratic Bézier curves), and `hmtx` (per-glyph
  horizontal advance width). It parses the **entire** font — no code point
  filtering/subsetting in this slice, since this is a general-purpose
  library and restricting the character set now would break non-Spanish,
  non-ASCII users. Subsetting to reduce compiled artifact size is a
  documented future optimization, not part of this slice.
- `Plotto.Font.DejaVuSans` is a thin wrapper: a module attribute
  `@parsed Plotto.Font.TrueType.parse!(File.read!(@font_path))`, with
  `@external_resource @font_path` so Mix recompiles this module if the
  `.ttf` file ever changes. Parsing happens **once, at compile time**
  (whether compiling Plotto itself or a project that depends on it) — the
  parsed representation is embedded as a literal term in the compiled
  `.beam`. At runtime, `Plotto.Font.DejaVuSans.font/0` just returns that
  term: no file I/O, no re-parsing, no `Agent`/`persistent_term` caching
  needed.
- `Plotto.Font.Glyph.rasterize/4` (glyph, x, y, canvas) converts one
  glyph's outline into a coverage mask via scanline fill (non-zero winding
  rule) and draws it onto the (4x) canvas at the given position, then
  reports the horizontal advance (from `hmtx`) so the caller can position
  the next character.
- `Plotto.PNG.Rasterizer` handles a `<text>` node by looking up each
  character's glyph via `cmap`, rendering it via `Plotto.Font.Glyph`, and
  advancing the cursor — no kerning between pairs, no bidi/shaping.
  Characters missing from the font's `cmap` are rendered as blank advance
  (skip the glyph draw, still advance by a fallback width) rather than
  raising, so one unsupported character doesn't fail the whole render.

## Text layout and stroke width in the Rasterizer

**Base coordinate scaling.** Every position/size value the Rasterizer
reads from the `Plotto.SVG.Element` tree (`<rect>`'s `x`/`y`/`width`/
`height`, `<circle>`'s `cx`/`cy`/`r`, `<line>`/`<polyline>` point
coordinates, `<text>`'s `x`/`y`) is expressed in final (1x, SVG/browser-
matching) pixel units by `Plotto.SVG.Renderer` — it has no notion of the
PNG pipeline's supersampling. Since the Canvas is sized at 4x, the
Rasterizer must multiply **every** such coordinate by the 4 supersampling
factor before drawing or computing derived positions from it. This
applies uniformly, before the font-size/stroke-width-specific scaling
described below (e.g. a `<text x="56" y="380">`'s draw-start x is derived
from `56 * 4`, not `56`, before the `text-anchor` offset is subtracted).

The SVG pipeline's `<text>` elements also carry a `font-size` attribute (`12`
for axis/tick labels, `18` for the title — see
`Plotto.Theme.font_size/0` / `title_font_size/0`) and a `text-anchor`
attribute (`"start"` default, `"middle"` for centered labels/title,
`"end"` for right-aligned y-axis tick labels). The Rasterizer must honor
both so PNG text layout matches the SVG's, per this spec's own Goals:

- **Font-size scaling.** Glyph outline coordinates and `hmtx` advance
  widths from `Plotto.Font.TrueType` are expressed in font design units
  (scaled by the font's `unitsPerEm`, from the `head` table — 2048 for
  DejaVu Sans). Before rasterizing a glyph, the Rasterizer scales outline
  coordinates and advances by `font_size / units_per_em`, then by the 4x
  supersampling factor, to get final subpixel coordinates on the 4x
  canvas.
- **`text-anchor` alignment.** Before drawing, the Rasterizer computes the
  text string's total advance width (sum of each character's scaled
  `hmtx` advance). For `text-anchor="middle"`, the drawing start x is
  `attrs["x"] - total_width / 2`; for `"end"`, `attrs["x"] - total_width`;
  for `"start"` (the default / absent attribute), `attrs["x"]` unchanged
  (`attrs["x"]` here is already 4x-scaled per "Base coordinate scaling"
  above — both operands in these formulas are in the same 4x subpixel
  units). This mirrors what the SVG pipeline gets for free from the
  browser's `text-anchor` support.
- **Stroke width.** SVG `<line>`/`<polyline>` elements in this codebase
  never emit a `stroke-width` attribute (see
  `Plotto.SVG.Renderer.Shared`/`.BarChart`/`.LineChart`), so it defaults
  to `1`, meaning a 1px-wide line in the final image. On the 4x supersampled
  canvas this must be drawn as a **4-subpixel-wide** line (i.e.
  `stroke-width * 4`, defaulting `stroke-width` to 1 when the attribute is
  absent), not a 1-subpixel Bresenham line — otherwise, after 4x4
  averaging, the line would cover only ~1/16th of each destination
  pixel's area and render much fainter than the SVG's 1px stroke. Exact
  thick-line algorithm is left to the plan (see "Open questions").

## Shape rasterization and PNG encoding

- `Plotto.PNG.Rasterizer` walks the same `Plotto.SVG.Element` tree the SVG
  pipeline produces: `<rect>` → scanline fill; `<line>`/`<polyline>` →
  thick Bresenham (see above); `<circle>` → filled disc via
  distance-from-center test; `<text>` → per-character glyph rendering as
  above. No per-shape AA logic — see "Canvas and supersampling" above.
  Elements are drawn in tree/document order (the same order the SVG
  pipeline would paint them in); each draw directly overwrites the
  affected pixels, no alpha compositing between overlapping shapes.
- **Color parsing.** Every `fill`/`stroke` attribute value in the element
  tree is a `"#RRGGBB"` hex string (from `Plotto.Theme`'s default palette,
  or from a caller-supplied `:colors` option — see `Plotto.Options`/
  `Plotto.Theme.color/2`). A small `Plotto.PNG.Color.parse/1` helper
  converts `"#RRGGBB"` into a packed `0xRRGGBBFF` pixel value (full
  opacity) for the Canvas. Any other format (3-digit hex, named colors
  like `"red"`, `rgb(...)`) is out of scope for this slice: `parse/1`
  returns `{:error, reason}`, which `Plotto.to_png/1` surfaces as
  `{:error, reason}` (and `to_png!/1` raises) rather than silently
  misrendering — consistent with `:colors` already being an unvalidated,
  free-form caller-supplied list today.
- `Plotto.PNG.Encoder.encode/1` serializes the final-resolution `Canvas`
  to a PNG binary: signature bytes, `IHDR` (color type 6 = truecolor with
  alpha, 8-bit depth), `IDAT` (each scanline prefixed with filter-type
  byte `0` = None, the whole filtered byte stream compressed via
  `:zlib.compress/1`, which produces a complete zlib-format stream as PNG
  requires), `IEND`. Each chunk's CRC is computed via `:erlang.crc32/1`
  (a built-in BIF — no separate CRC implementation needed).

## Testing strategy

- `Plotto.Font.TrueType`: parse the real embedded `DejaVuSans.ttf` (not a
  synthetic fixture, since it's the only font this slice ships), verify
  header/table presence and the outline of a couple of known glyphs
  (e.g. `"A"`, `"0"`).
- `Plotto.Font.DejaVuSans`: a smoke test that `font/0` returns parsed data
  purely from the compiled module (a literal term), with no filesystem
  access at runtime/test time — the `fonts/DejaVuSans.ttf` file only
  needs to exist at compile time.
- `Plotto.PNG.Canvas`: pixel-level tests for `fill_rect`/`fill_circle`/
  `draw_line`/`put_pixel`, and for `downsample/1` (a known 4x4 block of
  colors produces the expected averaged pixel).
- `Plotto.Font.Glyph`: rasterizing a known simple glyph produces a
  coverage mask with pixels set in the expected region.
- `Plotto.PNG.Rasterizer`: rendering a `BarChart`/`LineChart` produces a
  `Canvas` with bar-colored pixels at expected coordinates, and non-white
  pixels where title/axis text is expected.
- `Plotto.PNG.Encoder`: round-trip test — encode a small known `Canvas`,
  verify the PNG signature/header, and decompress the `IDAT` chunk via
  `:zlib.uncompress/1` to confirm the reconstructed scanline bytes match
  the original (undoing the filter-type-`0` byte prefix per scanline).
- Integration: `Plotto.to_png!/1` on a sample `BarChart`/`LineChart`
  produces a binary with a valid PNG signature and correct final
  (non-supersampled) dimensions.

## Open questions for the implementation plan

- Exact glyph outline scanline-fill algorithm details (active edge table
  construction, sub-pixel handling at the 4x supersampled resolution).
- Fallback advance width for glyphs missing from `cmap` (e.g. `hmtx`'s
  entry for glyph id 0 / `.notdef`, or a fixed value).
- Exact thick-line drawing algorithm for stroke widths above 1 subpixel
  (see "Text layout and stroke width in the Rasterizer" below) — e.g.
  parallel offset Bresenham passes vs. a dedicated thick-line algorithm.

## Relationship to the prior spec

This spec **supersedes** the PNG-related architecture and testing-strategy
text in `docs/superpowers/specs/2026-07-17-core-chart-slice-design.md`
(that spec's "PNG export pipeline" section sketched an analytic,
per-primitive anti-aliasing approach — e.g. "Xiaolin Wu style" lines —
before the supersampling approach here was chosen). Where the two
disagree on PNG-specific design, this document is authoritative; the
prior spec remains authoritative for the SVG pipeline, the module list
overview, and the non-goals it defined (OpenType/CFF out of scope, etc.).
