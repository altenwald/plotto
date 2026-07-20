# Plotto — Optional Chart Legend

**Status:** Draft
**Date:** 2026-07-21

## Summary

Adds an optional legend to `Plotto.BarChart` and `Plotto.LineChart`: a single
swatch + label entry, positioned in one of the four corners of the chart
(`:top_left`, `:top_right`, `:bottom_left`, `:bottom_right`). Off by default.

Both chart types currently render a single data series (`[%{label:, value:}]`).
`Plotto.BarChart` colors each bar individually by category index; `Plotto.LineChart`
draws the whole line in one color. The legend does **not** enumerate
categories — it identifies the series as a whole, the same way in both chart
types: one swatch (the series' primary color) plus a caller-supplied series
name.

## Goals

- New options, accepted by both `Plotto.BarChart.new/2` and
  `Plotto.LineChart.new/2` (via `Plotto.Chart.Builder`):
  - `:name` — string, the series' display name.
  - `:legend` — one of `:top_left`, `:top_right`, `:bottom_left`,
    `:bottom_right`. Absent/`nil` (default): no legend.
- When `:legend` is set and `:name` is present: render one legend entry (a
  color swatch + the name text) in the requested corner, in both SVG and PNG
  output, without visually colliding with the title, axis labels, bars,
  line, or points.
- When `:legend` is set but `:name` is `nil`: no legend is drawn and no
  layout space is reserved — same behavior as `:title` being absent today.
- `:legend` set to anything other than the four valid atoms is a validation
  error (`{:error, reason}` from `new/2`, `ArgumentError` from `new!/2`),
  surfaced the same way `Plotto.Data.validate/1` errors are today.
- Charts built without `:legend` render pixel-identical SVG/PNG output to
  today (no regression for existing callers).

## Non-goals (for this slice)

- Per-category/per-bar legend entries (e.g. one swatch per month). Out of
  scope because both chart types model a single series; multi-series
  support (if ever added) would revisit this.
- Multiple legend entries, legend wrapping, or auto-sizing the legend band
  to the text content — the reserved band is a fixed size regardless of
  `:name` length.
- Configurable swatch size, font size, or colors for the legend itself
  beyond what `Plotto.Theme` already defines.
- Validating `:name`'s type (must be a string) — left unvalidated,
  consistent with `:title` today.

## API

```elixir
Plotto.BarChart.new!(data, title: "Monthly Sales", name: "Sales", legend: :top_right)
Plotto.LineChart.new!(data, name: "Revenue", legend: :bottom_left)
```

## Options and validation

`Plotto.Options.build/1` gains two fields:

```elixir
%{
  # ...existing fields...
  name: Keyword.get(opts, :name),
  legend: Keyword.get(opts, :legend)
}
```

A new `Plotto.Options.validate/1` returns `:ok | {:error, reason}`:

- `:legend` absent or `nil` → `:ok`.
- `:legend` one of `:top_left`, `:top_right`, `:bottom_left`,
  `:bottom_right` → `:ok`.
- Any other `:legend` value → `{:error, "invalid legend position, got: #{inspect(value)}"}`.

`Plotto.Chart.Builder.new/3` runs `Data.validate/1` and `Options.validate/1`
(order: data first, matching current behavior of validating data before
building), returning the first error encountered. `new!/3` raises
`ArgumentError` with that reason, unchanged from today's contract.

## Theme constants

`Plotto.Theme` gains:

- `legend_swatch_size/0` — `10` (px, square swatch side).
- `legend_gap/0` — `6` (px, space between swatch and text).
- `legend_row_height/0` — `20` (px, vertical band reserved for the legend
  row).

These reuse the existing `font_size/0` (`12`) for the legend text and
`Theme.color(colors, 0)` for the swatch fill — no new color logic.

## Layout — reserving space

Legend space is reserved only when a legend will actually be drawn
(`legend` is a valid position **and** `name` is non-nil). When that's true,
each renderer computes an effective margin before deriving `plot_width`/
`plot_height`:

- `:top_left` / `:top_right` → `margin.top` increases by
  `Theme.legend_row_height()`.
- `:bottom_left` / `:bottom_right` → `margin.bottom` increases by
  `Theme.legend_row_height()`.

This inserts the legend as its own row, stacked below the title (top
positions) or below the x-axis tick labels (bottom positions), so it never
overlaps existing content. When no legend will be drawn, the margin is
exactly what it is today — zero change to existing chart output.

## Rendering

A new function in `Plotto.SVG.Renderer.Shared`, e.g.
`legend_elements(name, position, color, margin, width, height)`, returns
`[]` when `name` or `position` is `nil`, or `[swatch_rect, text_element]`
otherwise. To avoid measuring rendered text width (not available at the SVG
layout stage — only the PNG rasterizer resolves glyph widths, and only at
draw time), horizontal placement is anchor-based, matching what
`Plotto.PNG.Rasterizer` already supports for `text-anchor`:

- **Left positions** (`:top_left`, `:bottom_left`): swatch at
  `x = margin.left`; text at `x = margin.left + swatch_size + gap` with
  `text-anchor: start`.
- **Right positions** (`:top_right`, `:bottom_right`): text at
  `x = (width - margin.right) - swatch_size - gap` with `text-anchor: end`;
  swatch at `x = (width - margin.right) - swatch_size`.
- **Vertical**: swatch and text are vertically centered within the
  reserved band — the newly added slice of `margin.top` (top positions) or
  `margin.bottom` (bottom positions).
- Swatch fill and text fill: `Theme.color(opts.colors, 0)` and
  `Theme.text_color()` respectively (swatch = series color, text = normal
  label color, consistent with axis/tick labels).

`Plotto.SVG.Renderer.BarChart` and `Plotto.SVG.Renderer.LineChart` both:

1. Compute the effective margin (as above) before deriving `plot_width`/
   `plot_height`, replacing the direct `Theme.margin()` use.
2. Append `Shared.legend_elements(...)` to their `children` list.

No changes needed in `Plotto.PNG.Rasterizer`: it already draws `<rect>` and
`<text>` (with `start`/`end`/default `text-anchor`) generically from the
`Plotto.SVG.Element` tree, so the legend renders in PNG output for free
once it exists in that tree — the same "PNG reuses the SVG tree" property
the PNG export pipeline already relies on.

## Testing strategy

- `Plotto.Options.validate/1`: accepts the 4 valid positions and
  absent/`nil`; rejects any other atom/value.
- `Plotto.Chart.Builder`: `new/3` with `legend: :invalid` (or any
  non-atom) returns `{:error, _}`; `new!/3` raises `ArgumentError`.
- `Plotto.SVG.Renderer.BarChart` / `.LineChart`:
  - No `:legend` → output identical to today (regression check).
  - `:legend` position set, `:name` set → legend `<rect>` + `<text>`
    present at the expected coordinates for that position; margin-derived
    axis/bar/line positions reflect the reserved band.
  - `:legend` position set, `:name` absent → output identical to the
    no-legend case (nothing drawn, no space reserved).
  - All four positions covered for at least `BarChart`.
- PNG smoke test: a chart with `:legend` + `:name` set produces a valid PNG
  binary (same pattern as the existing PNG end-to-end tests).
- Update `examples/bar_chart.exs` and `examples/line_chart.exs` to pass
  `name:`/`legend:` in at least one example, regenerating their `.svg`/
  `.png` output files.

## Documentation

- `README.md`: document `:name` and `:legend` alongside the other chart
  options (`:title`, `:colors`, etc.), including the four valid positions.
- Moduledocs for `Plotto.BarChart` and `Plotto.LineChart` (and any
  `Plotto.Options`/`Plotto.Chart.Builder` reference docs that list
  options): mention the new options with the same level of detail as
  existing ones.

## Open questions for the implementation plan

- Exact vertical centering formula for swatch/text within the reserved
  band (baseline offset for the text vs. the swatch rect's `y`), following
  the same style already used for `y_label`/`x_label` in
  `Plotto.SVG.Renderer.Shared`.
