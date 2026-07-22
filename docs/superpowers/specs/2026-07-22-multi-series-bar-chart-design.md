# Plotto — Multi-Series Bar Chart (Phase 1)

**Status:** Draft
**Date:** 2026-07-22

## Summary

Replaces Plotto's single-series data model with a multi-series one: `data` becomes
a list of *series*, each carrying its own `:name` and its own list of
`%{label:, value:, attrs:}` points. `Plotto.BarChart` gains grouped-bar rendering
(N side-by-side bars per category, one per series, each colored via `:colors`
cycling per series index) and the legend becomes multi-entry (one swatch + name
row per series, stacked vertically). This is **Phase 1** of a two-phase project;
**Phase 2** (a separate spec/plan) gives `Plotto.LineChart` real multi-series
rendering (multiple polylines). During Phase 1, `LineChart` keeps working but
only renders its first series, ignoring any additional ones — see "LineChart
during Phase 1" below.

This spec **supersedes** the single-entry-legend design
(`docs/superpowers/specs/2026-07-21-chart-legend-design.md`) with respect to the
chart-level `:name` option and `Plotto.SVG.Renderer.Shared.legend_elements/6`'s
signature — both are replaced here. That spec's four-corner positioning
(`:top_left`/`:top_right`/`:bottom_left`/`:bottom_right`) and its bottom-band
anchoring fix (anchored to absolute canvas height, not `margin.bottom`) remain
authoritative and unchanged.

## Goals

- New `data` shape for `Plotto.BarChart.new/2` (and, structurally, `LineChart.new/2`
  since both share `Plotto.Data`/`Plotto.Chart.Builder`):

  ```elixir
  [
    %{name: "Sales", data: [%{label: "Jan", value: 42}, %{label: "Feb", value: 58}]},
    %{name: "Costs", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 15}]}
  ]
  ```

  A single series is simply a one-element list — there is no separate
  "flat" shorthand.
- `Plotto.BarChart` renders one bar per series per category, grouped
  side-by-side within each category's band, each series colored via
  `Theme.color(colors, series_index)`.
- Legend (`:legend` option, unchanged four-position API) renders one row per
  series (swatch + series name), stacked vertically, when `:legend` is set.
- Existing single-series callers must migrate to the new shape — this is a
  breaking change, acceptable pre-1.0.

## Non-goals (for this slice)

- `Plotto.LineChart` multi-series rendering (multiple polylines) — Phase 2,
  separate spec/plan. Phase 1 only guarantees `LineChart` doesn't crash and
  keeps rendering correctly for the (still-common) single-series case.
- Stacked bar charts (bars summed on top of each other) — only grouped
  (side-by-side) bars are in scope.
- Per-series color overrides independent of `:colors` cycling (e.g. a
  `color:` key on an individual series) — colors are always
  `Theme.color(opts.colors, series_index)`.
- Series with mismatched category sets (e.g. one series covering Jan-Jun,
  another Jan-Mar) — rejected by validation, not supported via padding/nulls.
- Gaps/spacing between grouped bars within one category — bars are flush
  against each other, per this spec's chosen layout (see "Grouped bar
  layout").
- Any change to `Plotto.LineChart`'s or `Plotto.BarChart`'s `:width`,
  `:height`, `:title` options, or to PNG export — unaffected by this slice.

## Data model and validation

### Shape

```elixir
@type data_item :: %{
        required(:label) => String.t(),
        required(:value) => number(),
        optional(:attrs) => %{optional(String.t()) => String.t()}
      }

@type series :: %{
        required(:name) => String.t() | nil,
        required(:data) => [data_item()]
      }
```

`Plotto.BarChart.new/2`'s `data` argument (and `LineChart.new/2`'s, structurally)
is `[series()]`.

### `Plotto.Data.validate/1` (rewritten, not a new function — the old
flat-list validation is replaced, not kept alongside)

Validation rules, in order (first failure wins, matching the existing
fail-fast style):

1. `data` must be a non-empty list. `{:error, "data must not be empty"}` for
   `[]`; `{:error, "data must be a list"}` for a non-list — same messages as
   today, now checked at the series-list level.
2. Each element must be a map with `:name` (a `String.t()` or `nil`) and
   `:data` (a list) — otherwise `{:error, "invalid series, expected a map with :name and :data, got: ..."}`.
3. Each series' `:data` must be non-empty and each item must pass today's
   existing per-item checks (`:label` a string, `:value` a non-negative
   number) — reusing the existing `item_error/1` logic and error message
   wording, just applied per-series. An empty series `:data` is
   `{:error, "series data must not be empty for series: ..."}` (name or
   index identifies which one).
4. All series must have **identical, identically-ordered** `:label` lists.
   Compare against the first series'; on mismatch:
   `{:error, "series labels must match, expected [...], got [...] for series: ..."}`.
5. If there are 2 or more series, every series must have a non-nil `:name`
   (a `String.t()`). With exactly 1 series, `:name` may be `nil`.
   `{:error, "series name is required when there are multiple series"}`.

## Options and struct changes

- The chart-level `:name` option (added in the single-entry-legend spec) is
  **removed** — `Plotto.Options.build/1` no longer has a `:name` field.
  `:legend` (the four-position atom, validated the same way as before) is
  unchanged.
- `:colors` keeps its existing shape (`[String.t()]`, defaulting to the
  5-color palette) but is now interpreted **per series** —
  `Theme.color(opts.colors, series_index)` — reusing `Theme.color/2`'s
  existing cycling behavior unchanged.
- `Plotto.BarChart` (and `Plotto.LineChart`) typespecs:

  ```elixir
  @type series :: %{name: String.t() | nil, data: [data_item()]}
  @type t :: %__MODULE__{data: [series()], opts: options()}
  ```

  `options()` drops `:name`.

## Layout and rendering (`Plotto.SVG.Renderer.BarChart`)

- `labels` are read from the **first** series' `:data` (all series validated
  identical).
- `max_value` is computed across **all** series:
  `data |> Enum.flat_map(& &1.data) |> Enum.map(& &1.value) |> Enum.max()`.
- `Plotto.Axis.categorical_scale/2` is unchanged — it still produces one band
  per category. Sub-dividing a band into per-series bars is the renderer's
  job, not `Axis`'s.
- **Grouped bar layout**, per category band: the existing 80%-central /
  10%-margin-each-side proportions are unchanged; the 80% inner width is
  divided into `n_series` equal-width sub-bars with **no gap** between them
  (flush against each other). For series index `i` (0-based) of `n_series`:

  ```
  inner_width  = band.band_width * 0.8
  inner_x      = margin.left + band.band_x + band.band_width * 0.1
  sub_width    = inner_width / n_series
  bar_x        = inner_x + i * sub_width
  ```

  Bar height/`y` positioning (value → pixel via `Axis.linear_scale/3`) is
  unchanged from today's single-series logic, applied per series' value at
  that category.
- Each series' bars share one fill color: `Theme.color(opts.colors, i)`.
- Per-item `:attrs` passthrough is unchanged, still merged onto each bar's
  `<rect>`.

## Legend (multi-entry)

`Plotto.SVG.Renderer.Shared.legend_elements/6`'s signature changes: instead
of a single `(name, legend, color, margin, width, height)`, it takes a list
of `{name, color}` pairs (one per series) plus `legend, margin, width, height`
— exact arity/argument order is left to the implementation plan, but the
contract is: given `[{name, color}, ...]` and a position, return `[]` if the
list is empty or `legend` is `nil`, otherwise one swatch+text pair per
series, stacked vertically in series order (first series topmost, regardless
of `:top_*`/`:bottom_*` — no reversal for bottom positions), each row
`Theme.legend_row_height()` tall. Horizontal placement (left/right anchor,
swatch-then-text or text-then-swatch ordering) is unchanged per row from the
single-entry design.

`Plotto.SVG.Renderer.Shared.effective_margin/3` reserves
`Theme.legend_row_height() * n_series` (instead of a flat
`legend_row_height()`) in `margin.top` or `margin.bottom`, following the same
top-anchored-to-margin / bottom-anchored-to-absolute-height split established
(and bug-fixed) in the prior legend spec.

A series with `name: nil` cannot reach the legend-rendering path in practice,
since validation requires non-nil names whenever there are 2+ series (the
only case where a legend has more than one row); a single-series chart with
`name: nil` and `:legend` set renders one row with an empty text label (swatch
only, no visible name) — this matches today's already-existing behavior for
a single unnamed series, just expressed through the list-of-one-entry code
path instead of a special case.

## LineChart during Phase 1

`Plotto.SVG.Renderer.LineChart.render/1` is updated minimally so the module
keeps compiling and working correctly for its still-most-common case: it reads
`List.first(data).data` and renders exactly that one series' polyline/points,
ignoring any further series in the list. This is a stopgap, not a design
statement about the final multi-series line behavior — Phase 2 replaces it
with real multi-series rendering (N polylines, N point sets, colored and
legended like `BarChart`'s series). `Plotto.LineChart`'s moduledoc should
note this limitation explicitly ("only the first series is drawn; full
multi-series support is planned") so it isn't mistaken for a bug.

## Testing strategy

- `Plotto.Data.validate/1`: rewritten test suite covering — valid
  single-series list, valid multi-series list, empty `data`, non-list
  `data`, a series missing `:name`/`:data`, a series with empty `:data`, an
  invalid item within a series (bad label/value, matching today's existing
  per-item error cases), mismatched labels across series, a 2+-series chart
  with a `nil` name on one series.
- `Plotto.Chart.Builder`/`Plotto.BarChart`/`Plotto.LineChart` `new/2`/`new!/2`:
  updated to build/accept the new shape; existing error-tuple/raise
  contracts unchanged.
- `Plotto.SVG.Renderer.BarChart`: single-series rendering unchanged
  (regression-checked against today's pixel positions); multi-series
  rendering tested for 2 and 3 series — bar count per category, sub-bar
  widths/x-positions matching the flush/no-gap formula, correct per-series
  color, correct `max_value` spanning all series.
- `Plotto.SVG.Renderer.Shared`: `legend_elements/6`'s new list-based contract
  — empty list/`nil` legend → `[]`; 1 entry → same visual output as the prior
  single-entry design (regression check against the already-fixed
  top/bottom-anchoring math); N entries → correct stacked row positions,
  reserved-margin height scales with N.
- `Plotto.SVG.Renderer.LineChart`: regression test that a multi-series input
  still renders (only the first series' line/points, no crash).
- End-to-end (`Plotto.to_svg!/1`/`to_png!/1`): a 2-series bar chart with
  legend renders both series' names/colors in SVG and produces a valid PNG.
- Update `examples/bar_chart.exs` to the new data shape; add a new example
  (or extend the existing one) demonstrating 2 series ("Sales"/"Costs") with
  a legend. Regenerate `.svg`/`.png`. Update `examples/line_chart.exs` to the
  new shape too (single series, since Phase 2 isn't done yet).

## Documentation

- `Plotto.BarChart`, `Plotto.LineChart`: rewrite moduledocs, `## Options`
  (remove `:name`, update `:colors` wording to "cycled per series"),
  `@type series`/`@type t`, and all doctest examples for the new data shape.
  `LineChart`'s moduledoc gains the Phase 1 limitation note above.
- `Plotto.Data`: update moduledoc/whatever doc comments describe the
  validated shape (currently `@moduledoc false`, so this is mostly internal,
  but keep it accurate for future readers).
- `Plotto.Options`: remove `:name` handling; no doc changes needed since it's
  `@moduledoc false`.
- `lib/plotto.ex`: update the top-level `## Options` summary (six options →
  five: `:width`, `:height`, `:title`, `:colors`, `:legend`) and its
  data-shape example.
- `README.md`: update the `## Usage` and `## Examples` snippets to the new
  data shape; add a multi-series example.

## Open questions for the implementation plan

- Exact function signature/arity for the new `Shared.legend_elements` (list
  of `{name, color}` pairs vs. list of series maps vs. separate names/colors
  lists) — left to the plan to pick whichever reads cleanest against the
  existing `effective_margin/3` call site.
- Whether `Plotto.Data`'s per-series/per-item error messages should include
  a series index, a series name, or both, for the clearest error UX —
  left to the plan/implementation to decide via the existing error-message
  style (plain strings, no error codes).
