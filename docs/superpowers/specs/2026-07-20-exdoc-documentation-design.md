# Plotto — ExDoc Documentation

**Status:** Draft
**Date:** 2026-07-20

## Summary

Plotto's public API (`Plotto`, `Plotto.BarChart`, `Plotto.LineChart`) currently has minimal
`@moduledoc`/`@doc` coverage — enough to compile, not enough to be useful reference
documentation. This spec covers adding `ex_doc` as a dev dependency, configuring it to
generate a proper documentation site (with the README as the front page), tightening the
public structs' `@type` definitions so generated docs show real shapes instead of `map()`,
and expanding the public modules' docs with full option coverage and verified (doctest)
examples.

This is a documentation-only change: no runtime behavior changes anywhere in `lib/`.

## Goals

- `mix docs` generates a clean `doc/` site with no warnings, using the README as the
  front page.
- Every public function on `Plotto`, `Plotto.BarChart`, `Plotto.LineChart` has a `@doc`
  that explains what it does, documents every option/field it accepts, and includes at
  least one example.
- Examples are real doctests (`iex>` blocks executed via `doctest/1` in
  `test/plotto_test.exs`, already wired up for `Plotto.BarChart`/`Plotto.LineChart` —
  extended to cover more cases) wherever the example's result can be expressed as a
  single deterministic value. Where the raw result (an SVG string, a PNG binary) is too
  long/opaque to assert against literally, the doctest instead asserts a property of the
  result (e.g. `String.starts_with?(svg, "<svg")`) — this is a normal, valid ExUnit
  doctest pattern since only the final expression's value is compared.
- `Plotto.BarChart`/`Plotto.LineChart`'s `@type t` is precise: named `data_item` and
  `options` types replace the current `[map()]`/`map()` placeholders, each documented via
  `@typedoc`.

## Non-goals

- No separate guide/tutorial page (e.g. `guides/getting-started.md`) — out of scope for
  this pass, per explicit decision during brainstorming. The README remains the sole
  ExDoc "extra" page.
- No changes to internal (`@moduledoc false`) modules' documentation — they're invisible
  to ExDoc by design and stay that way.
- No changes to runtime validation, error messages, or any other behavior — this is
  strictly a documentation/type-annotation change.
- No Hex package metadata work (`description`/`licenses`/`links` in `mix.exs`'s
  `package/0`) — already a known, separately-tracked gap from the PNG pipeline work; not
  part of this task.

## `mix.exs` changes

- Add `{:ex_doc, "~> 0.40", only: :dev, runtime: false}` to `deps/0` (0.40.3 is the
  latest release as of this spec's writing — verify against `mix hex.info ex_doc` at
  implementation time in case a newer version has shipped). This is a dev-only
  dependency — it does not affect `Plotto`'s runtime dependency footprint (still zero)
  for library consumers.
- Add a `docs/0` private function, wired into `project/0` via `docs: docs()`:
  ```elixir
  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/altenwald/plotto"
    ]
  end
  ```
- No `groups_for_modules` needed: every module except `Plotto`, `Plotto.BarChart`, and
  `Plotto.LineChart` has `@moduledoc false`, and ExDoc omits `@moduledoc false` modules
  from generated docs entirely — so the doc site will only ever show these three modules
  without any extra grouping configuration.

## Type refinement

In both `lib/plotto/bar_chart.ex` and `lib/plotto/line_chart.ex`, replace the current
loose `@type t :: %__MODULE__{data: [map()], opts: map()}` with:

```elixir
@typedoc """
One data point: a category `:label`, its numeric `:value`, and optional `:attrs` —
arbitrary attribute/value pairs (e.g. `phx-click`, `data-*`) copied verbatim onto the
corresponding SVG/PNG element for the point, without Plotto depending on Phoenix or
LiveView.
"""
@type data_item :: %{
        required(:label) => String.t(),
        required(:value) => number(),
        optional(:attrs) => %{optional(String.t()) => String.t()}
      }

@typedoc """
Chart options, after defaults from `Plotto.Theme` have been applied. Passed as a
keyword list to `new/2`/`new!/2`; stored in this resolved map form on the chart struct.
"""
@type options :: %{
        width: pos_integer(),
        height: pos_integer(),
        title: String.t() | nil,
        colors: [String.t()]
      }

@type t :: %__MODULE__{data: [data_item()], opts: options()}
```

These are pure type/doc annotations — `Plotto.Data`/`Plotto.Options` already perform the
actual runtime validation and defaulting; this section does not change or duplicate that.

## Documentation content

### `Plotto.BarChart` / `Plotto.LineChart`

- `@moduledoc`: what the chart is, when to use it (bar for categorical comparison, line
  for a single trend across categories), and one complete example (data + opts + render).
- `new/2`'s `@doc`: documents every option (`:width`, `:height`, `:title`, `:colors`)
  with its default (referencing `Plotto.Theme`'s defaults by value, e.g. "defaults to
  600"), documents the `data_item` shape including `:attrs`' LiveView-passthrough
  purpose, and includes at least two doctests: the existing minimal one, plus one
  exercising `:title`/`:colors` options and an `:attrs` entry.
- `new!/2`'s `@doc` stays a one-liner ("Same as `new/2`, but raises `ArgumentError`..."),
  cross-referencing `new/2` for the full option/shape documentation (avoids duplicating
  the same content twice).

### `Plotto`

- `@moduledoc` gains an "## Options" section summarizing the 4 common options shared by
  both chart types (cross-referencing `Plotto.BarChart`/`Plotto.LineChart` for the
  authoritative per-field docs, not re-stating them in full), and a short note on the
  `{:ok, _} | {:error, _}` / `!`-raising error contract shared by `to_svg`/`to_png`.
- `to_svg/1`/`to_png/1`: `@doc` gains a doctest asserting a property of the result
  (`String.starts_with?(svg, "<svg")` / PNG signature check) rather than the full
  binary, per the Goals section's doctest pattern.
- `to_svg!/1`/`to_png!/1`: `@doc` explicitly states they raise `ArgumentError` on
  failure (already partially true in prose; make it unambiguous), with a doctest for
  the success path (same result-property-check pattern).

## Testing / verification

- `mix docs` runs clean, no warnings (e.g. no broken doc references, no missing
  `@typedoc` for a referenced type).
- `mix test` — all doctests (existing + newly added) pass, full suite green, no
  regressions to the 117 existing tests / 2 existing doctests.
- `mix format --check-formatted` clean.
- Manual check: open the generated `doc/index.html` and `doc/Plotto.BarChart.html` (or
  equivalent) and visually confirm the options table/type info renders sensibly — this
  mirrors the "actually look at the output" discipline used for the PNG pipeline's visual
  checks, applied here to documentation output instead of chart images.
