# ExDoc Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mix docs` produce a genuinely useful ExDoc site for Plotto's public API (`Plotto`, `Plotto.BarChart`, `Plotto.LineChart`), with full option/type documentation and verified (doctest) examples.

**Architecture:** Add `ex_doc` as a dev-only dependency and configure it to use the README as the front page. Tighten `Plotto.BarChart`/`Plotto.LineChart`'s `@type t` into named, documented `data_item`/`options` types. Expand `@moduledoc`/`@doc` across the three public modules with full option coverage and doctests. No runtime behavior changes anywhere.

**Tech Stack:** Elixir ~> 1.17, ExDoc ~> 0.40 (dev-only). No new runtime dependencies.

**Related spec:** `docs/superpowers/specs/2026-07-20-exdoc-documentation-design.md`

---

## Conventions used throughout this plan

- Run a single test file with: `mix test path/to/file_test.exs`
- Run the whole suite (including all doctests) with: `mix test`
- Generate docs with: `mix docs` (writes to `doc/`)
- This plan touches `mix.exs`, `lib/plotto.ex`, `lib/plotto/bar_chart.ex`,
  `lib/plotto/line_chart.ex`, and `test/plotto_test.exs`. `test/plotto_test.exs`
  currently has `doctest Plotto.BarChart` and `doctest Plotto.LineChart` — these
  already discover and run every doctest added to those two modules' `@doc`/
  `@moduledoc` blocks automatically, no changes needed there. It does **not** yet have
  `doctest Plotto` — Task 4 adds it (Step 2 below), since without it the four new
  `iex>` examples added to `lib/plotto.ex` would silently never run (confirmed during
  plan review: `mix test` reports 0 failures either way, but the examples are only
  actually executed once `doctest Plotto` is present).
- Current confirmed `Plotto.Theme` defaults (verified during spec review — hardcode
  these as plain text in docs rather than interpolating them; `@doc` string
  interpolation of another module's function does compile fine, this is simply about
  avoiding an unnecessary compile-time coupling that would trigger extra
  recompilation if `Theme`'s defaults ever change): `default_width/0` → `600`,
  `default_height/0` → `400`, `default_colors/0` → a 5-entry hex list starting with
  `"#4E79A7"`.

---

### Task 1: Add ExDoc and configure `mix.exs`

**Files:**
- Modify: `mix.exs`

- [ ] **Step 1: Add the dependency and docs config**

Replace the full contents of `mix.exs` with:

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
      package: package(),
      docs: docs()
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

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/altenwald/plotto"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
```

(Verify `~> 0.40` is still current via `mix hex.info ex_doc` before committing — bump
the version constraint if a newer release has shipped since this plan was written.)

- [ ] **Step 2: Fetch the new dependency**

Run: `mix deps.get`
Expected: `ex_doc` and its own dependencies (`earmark_parser`, `makeup*`) are fetched
successfully.

- [ ] **Step 3: Generate docs to confirm the baseline works**

Run: `mix docs`
Expected: succeeds, prints something like `Generated plotto app` /
`Docs successfully generated`, creates a `doc/` directory. It's expected that the
generated site is still fairly bare at this point (Tasks 2-4 haven't run yet) — this
step is only confirming the *plumbing* (dependency, config, README-as-main-page) works
before expanding content.

- [ ] **Step 4: Run the full test suite to confirm nothing broke**

Run: `mix test`
Expected: PASS — `2 doctests, 117 tests, 0 failures` (unchanged from before this task;
adding a dev dependency and doc config doesn't touch runtime code).

- [ ] **Step 5: Verify formatting and commit**

Run: `mix format --check-formatted`
Expected: clean (mix.exs is a `.exs` file covered by the project's formatter config).

```bash
git add mix.exs mix.lock
git commit -m "Add ex_doc dependency and docs configuration"
```

(`mix.lock` will be modified/created by `mix deps.get` in Step 2 — include it.)

---

### Task 2: Document `Plotto.BarChart`

**Files:**
- Modify: `lib/plotto/bar_chart.ex`

- [ ] **Step 1: Replace the full contents of `lib/plotto/bar_chart.ex`**

```elixir
defmodule Plotto.BarChart do
  @moduledoc """
  A bar chart: one bar per data item, bar height proportional to `:value`.

  Use a bar chart to compare a value across categories — sales per month, votes per
  candidate, and similar "one number per category" data.

  ## Example

      data = [
        %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
        %{label: "Feb", value: 25}
      ]

      chart = Plotto.BarChart.new!(data, title: "Sales", colors: ["#4E79A7", "#F28E2B"])
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  """

  defstruct [:data, :opts]

  @typedoc """
  One data point: a category `:label`, its numeric `:value`, and optional `:attrs` —
  arbitrary attribute/value pairs (e.g. `"phx-click"`, `"data-*"`) copied verbatim onto
  the corresponding SVG/PNG element for that bar, without Plotto depending on Phoenix
  or LiveView in any way.
  """
  @type data_item :: %{
          required(:label) => String.t(),
          required(:value) => number(),
          optional(:attrs) => %{optional(String.t()) => String.t()}
        }

  @typedoc """
  Chart options, after defaults have been applied. Passed as a keyword list to
  `new/2`/`new!/2`; stored in this resolved map form on the chart struct
  (`t:t/0`'s `:opts` field).
  """
  @type options :: %{
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          colors: [String.t()]
        }

  @type t :: %__MODULE__{data: [data_item()], opts: options()}

  @doc """
  Builds a bar chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` is a list of `t:data_item/0` maps: each needs a `:label` (string) and a
  non-negative `:value` (number), and may include `:attrs` for per-bar attribute
  passthrough (e.g. Phoenix LiveView's `phx-click`).

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings, cycled one per bar. Defaults
      to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.

  ## Examples

      iex> {:ok, chart} = Plotto.BarChart.new([%{label: "Jan", value: 10}])
      iex> chart.data
      [%{label: "Jan", value: 10}]

      iex> {:ok, chart} =
      ...>   Plotto.BarChart.new(
      ...>     [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}],
      ...>     title: "Sales",
      ...>     colors: ["#000000"]
      ...>   )
      iex> {chart.opts.title, chart.opts.colors}
      {"Sales", ["#000000"]}

      iex> Plotto.BarChart.new([])
      {:error, "data must not be empty"}

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
```

- [ ] **Step 2: Run the doctests to verify they pass**

Run: `mix test test/plotto_test.exs`
Expected: PASS, with more doctest examples now running than before (the exact count
grows since `doctest Plotto.BarChart` now discovers the 3 new `iex>` examples in
`new/2`'s expanded `@doc`).

- [ ] **Step 3: Run the full suite**

Run: `mix test`
Expected: PASS, 0 failures.

- [ ] **Step 4: Verify formatting**

Run: `mix format --check-formatted`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/bar_chart.ex
git commit -m "Expand Plotto.BarChart documentation with types and doctests"
```

---

### Task 3: Document `Plotto.LineChart`

**Files:**
- Modify: `lib/plotto/line_chart.ex`

- [ ] **Step 1: Replace the full contents of `lib/plotto/line_chart.ex`**

```elixir
defmodule Plotto.LineChart do
  @moduledoc """
  A line chart: a single line connecting one point per data item.

  Use a line chart to show a trend across ordered categories — a metric over time,
  for example. Plotto's line charts render exactly one line; multi-series line charts
  (multiple lines on one chart) are not supported.

  ## Example

      data = [
        %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
        %{label: "Feb", value: 25}
      ]

      chart = Plotto.LineChart.new!(data, title: "Trend", colors: ["#4E79A7"])
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  """

  defstruct [:data, :opts]

  @typedoc """
  One data point: a category `:label`, its numeric `:value`, and optional `:attrs` —
  arbitrary attribute/value pairs (e.g. `"phx-click"`, `"data-*"`) copied verbatim onto
  the corresponding SVG/PNG element for that point (a small circle marker), without
  Plotto depending on Phoenix or LiveView in any way.
  """
  @type data_item :: %{
          required(:label) => String.t(),
          required(:value) => number(),
          optional(:attrs) => %{optional(String.t()) => String.t()}
        }

  @typedoc """
  Chart options, after defaults have been applied. Passed as a keyword list to
  `new/2`/`new!/2`; stored in this resolved map form on the chart struct
  (`t:t/0`'s `:opts` field).
  """
  @type options :: %{
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          colors: [String.t()]
        }

  @type t :: %__MODULE__{data: [data_item()], opts: options()}

  @doc """
  Builds a line chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` is a list of `t:data_item/0` maps: each needs a `:label` (string) and a
  non-negative `:value` (number), and may include `:attrs` for per-point attribute
  passthrough (e.g. Phoenix LiveView's `phx-click`).

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings; only the *first* color is
      used, as the line's stroke color (line charts render a single line, so there's
      no cycling). Defaults to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.

  ## Examples

      iex> {:ok, chart} = Plotto.LineChart.new([%{label: "Jan", value: 10}])
      iex> chart.data
      [%{label: "Jan", value: 10}]

      iex> {:ok, chart} =
      ...>   Plotto.LineChart.new(
      ...>     [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}],
      ...>     title: "Trend",
      ...>     colors: ["#000000"]
      ...>   )
      iex> {chart.opts.title, chart.opts.colors}
      {"Trend", ["#000000"]}

      iex> Plotto.LineChart.new([])
      {:error, "data must not be empty"}

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
```

- [ ] **Step 2: Run the doctests to verify they pass**

Run: `mix test test/plotto_test.exs`
Expected: PASS, doctest count grows again (3 new examples from `LineChart.new/2`).

- [ ] **Step 3: Run the full suite**

Run: `mix test`
Expected: PASS, 0 failures.

- [ ] **Step 4: Verify formatting**

Run: `mix format --check-formatted`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/line_chart.ex
git commit -m "Expand Plotto.LineChart documentation with types and doctests"
```

---

### Task 4: Document `Plotto` (top-level module)

**Files:**
- Modify: `lib/plotto.ex`
- Modify: `test/plotto_test.exs`

- [ ] **Step 1: Replace the full contents of `lib/plotto.ex`**

```elixir
defmodule Plotto do
  @moduledoc """
  Plotto generates SVG and PNG charts in pure Elixir.

  ## Example

      chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}], title: "Sales")
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  ## Options

  Both `Plotto.BarChart` and `Plotto.LineChart` accept the same four options via
  `new/2`/`new!/2`: `:width`, `:height`, `:title`, `:colors`. See
  `Plotto.BarChart.new/2` (or `Plotto.LineChart.new/2`) for their exact defaults and
  shapes — line charts differ slightly in how `:colors` is used (only the first color
  is applied, as the single line's stroke), documented there.

  ## Error handling

  `to_svg/1` and `to_png/1` return `{:ok, result} | {:error, reason}` and never raise.
  `to_svg!/1` and `to_png!/1` return the result directly and raise `ArgumentError` if
  rendering fails.
  """

  alias Plotto.SVG.{Renderer, Serializer}
  alias Plotto.PNG.{Canvas, Encoder, Rasterizer}

  @doc """
  Renders a chart (`Plotto.BarChart` or `Plotto.LineChart`) to an SVG string.

  Returns `{:ok, svg}` on success or `{:error, reason}` if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> {:ok, svg} = Plotto.to_svg(chart)
      iex> String.starts_with?(svg, "<svg")
      true

  """
  @spec to_svg(struct()) :: {:ok, String.t()} | {:error, String.t()}
  def to_svg(chart) do
    {:ok, chart |> Renderer.render() |> Serializer.serialize()}
  rescue
    error -> {:error, Exception.message(error)}
  end

  @doc """
  Same as `to_svg/1`, but returns the SVG string directly and raises `ArgumentError`
  if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> Plotto.to_svg!(chart) |> String.starts_with?("<svg")
      true

  """
  @spec to_svg!(struct()) :: String.t()
  def to_svg!(chart) do
    case to_svg(chart) do
      {:ok, svg} -> svg
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Renders a chart (`Plotto.BarChart` or `Plotto.LineChart`) to a PNG binary.

  Returns `{:ok, png}` on success or `{:error, reason}` if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> {:ok, png} = Plotto.to_png(chart)
      iex> binary_part(png, 0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>
      true

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

  @doc """
  Same as `to_png/1`, but returns the PNG binary directly and raises `ArgumentError`
  if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> Plotto.to_png!(chart) |> binary_part(0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>
      true

  """
  @spec to_png!(struct()) :: binary()
  def to_png!(chart) do
    case to_png(chart) do
      {:ok, png} -> png
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
```

- [ ] **Step 2: Register the module's doctests**

`test/plotto_test.exs` currently has `doctest Plotto.BarChart` and
`doctest Plotto.LineChart` but no `doctest Plotto` — without it, the four `iex>`
examples just added to `lib/plotto.ex` would never actually run (ExUnit's `doctest`
macro only extracts and runs examples from modules it's explicitly told about; adding
`@doc` examples alone does not register them). Add the line so the top of the test
module reads:

```elixir
defmodule PlottoTest do
  use ExUnit.Case, async: true

  doctest Plotto
  doctest Plotto.BarChart
  doctest Plotto.LineChart

  alias Plotto.{BarChart, LineChart}
```

(Only the three `doctest` lines are new/changed — leave the rest of the file, including
the `alias` line and everything below it, untouched.)

- [ ] **Step 3: Run the doctests to verify they pass**

Run: `mix test test/plotto_test.exs`
Expected: PASS. All 4 public functions (`to_svg/1`, `to_svg!/1`, `to_png/1`,
`to_png!/1`) now have at least one doctest each, on top of the existing explicit
tests in this same file. Confirm the reported doctest count actually increased by 4
compared to the count before this step (it should include the new `Plotto` doctests,
not just `Plotto.BarChart`/`Plotto.LineChart`'s) — if it didn't, `doctest Plotto` was
not added correctly.

- [ ] **Step 4: Run the full suite**

Run: `mix test`
Expected: PASS, 0 failures. Note the total doctest count in the output (it will be
noticeably higher than the "2 doctests" baseline from before this plan — that's
expected and correct, not a regression signal).

- [ ] **Step 5: Verify formatting**

Run: `mix format --check-formatted`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/plotto.ex test/plotto_test.exs
git commit -m "Expand Plotto module documentation with options summary and doctests"
```

---

### Task 5: Regenerate docs and verify the output

**Files:** none (verification only)

- [ ] **Step 1: Regenerate the doc site**

Run: `rm -rf doc && mix docs`
Expected: succeeds with no warnings (no "documentation references function that
doesn't exist", no broken `t:type/0`/`` `Module.function/arity` `` link warnings — ExDoc
prints these as warnings during generation, not as a hard failure, so check the
output text even if the command exits 0). If any warning appears (e.g. a reference to
a hidden/`@moduledoc false` module — this can happen if a doc string backtick-links to
an internal module like `Plotto.Theme`), fix the referencing doc text (drop the
backtick-link, or replace it with the concrete value) in the relevant file from
Task 2/3/4, then re-run this step before proceeding.

- [ ] **Step 2: Visually inspect the generated site**

Open `doc/index.html` (e.g. via the Read tool, since it can render images but not
HTML directly — instead use `open doc/index.html` on macOS, or read the raw HTML/text
content of `doc/Plotto.html`, `doc/Plotto.BarChart.html`, `doc/Plotto.LineChart.html`
to confirm the rendered content looks right) and confirm:

- The front page shows the README content (title "Plotto", the usage examples).
- Only three modules appear in the sidebar: `Plotto`, `Plotto.BarChart`,
  `Plotto.LineChart` (every other module has `@moduledoc false` and must NOT appear).
- `Plotto.BarChart`'s page shows the `data_item` and `options` types with their
  `@typedoc` text, and `new/2`'s docs show the "## Options" bullet list and the three
  `## Examples` doctest blocks.
- Same checks for `Plotto.LineChart`.
- `Plotto`'s page shows the "## Options" and "## Error handling" sections, and all
  four functions (`to_svg/1`, `to_svg!/1`, `to_png/1`, `to_png!/1`) have visible
  doctest examples.

If anything looks wrong (missing section, broken type link, a module that shouldn't
be visible showing up), fix it and re-run Step 1 before proceeding — don't just note
it and move on.

- [ ] **Step 3: Final full-suite check**

Run: `mix test && mix format --check-formatted && mix compile --force --warnings-as-errors`
Expected: all three commands succeed cleanly.

- [ ] **Step 4: Report the final doctest count**

Run: `mix test 2>&1 | tail -5` and note the exact `N doctests, M tests, 0 failures`
line in your final report for this task, so the plan's completion can be verified
against a concrete number.

No commit for this task — it's verification-only, nothing to stage.

---

## Definition of done

- `mix docs` runs clean, no warnings, no missing dependency errors.
- `doc/index.html` shows the README as the front page; only `Plotto`,
  `Plotto.BarChart`, `Plotto.LineChart` appear as documented modules.
- Every public function on those three modules has a `@doc` with at least one
  worked example, and `Plotto.BarChart`/`Plotto.LineChart` have named, documented
  `data_item`/`options` types instead of `map()`.
- `mix test` passes with 0 failures, doctest count strictly higher than the
  pre-plan baseline of 2.
- `mix format --check-formatted` and `mix compile --warnings-as-errors` are clean.
- No runtime behavior changed anywhere — `git diff` outside `lib/plotto.ex`,
  `lib/plotto/bar_chart.ex`, `lib/plotto/line_chart.ex`, `mix.exs`, `mix.lock`,
  `test/plotto_test.exs` should be empty.
