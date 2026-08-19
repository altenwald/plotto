# Multi-Series Bar Chart (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Plotto's single-series data model with a multi-series one, add grouped-bar rendering to `Plotto.BarChart`, and upgrade the legend to multi-entry (one row per series).

**Architecture:** `data` becomes `[%{name: String.t() | nil, data: [data_item()]}]` (a list of series) instead of a flat `[data_item()]`. `Plotto.Data.validate/1` is rewritten to validate this shape (matching labels across series, name required for 2+ series). `Plotto.SVG.Renderer.Shared`'s legend functions become list-based (one `{name, color}` entry per series, stacked vertically). `Plotto.SVG.Renderer.BarChart` draws grouped bars (N per category) colored per series. `Plotto.SVG.Renderer.LineChart` gets a minimal compatibility update (renders only the first series) — full multi-series line rendering is a separate future phase.

**Tech Stack:** Elixir, ExUnit. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-22-multi-series-bar-chart-design.md`

---

## Before you start

This is a breaking change to a shared validator (`Plotto.Data.validate/1`), used by both `Plotto.BarChart` and `Plotto.LineChart` via `Plotto.Chart.Builder`. **The full test suite will NOT be green again until Task 7 is done.** Tasks 1-6 each verify only their own directly-relevant test file(s) — do not be alarmed when `mix test` (the whole suite) shows unrelated failures in files a task hasn't touched yet; that's expected mid-plan, not a regression you introduced. Task 7 is where `test/plotto_test.exs` (which exercises the full render pipeline end-to-end, including doctests in `lib/plotto.ex` that call `Plotto.to_svg/1`) is rewritten and should bring the whole suite back to green. Task 10 does the final whole-suite verification.

Work directly on `main` in this repository (no worktree) — confirmed with the user.

Run `mix test` once now to confirm today's baseline: `14 doctests, 151 tests, 0 failures`.

---

### Task 1: Rewrite `Plotto.Data.validate/1` for multi-series data

**Files:**
- Modify: `lib/plotto/data.ex` (full rewrite)
- Test: `test/plotto/data_test.exs` (full rewrite)

- [x] **Step 1: Write the failing tests**

Replace the entire contents of `test/plotto/data_test.exs`:

```elixir
defmodule Plotto.DataTest do
  use ExUnit.Case, async: true

  alias Plotto.Data

  test "a valid single-series list passes validation" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]
    assert Data.validate(data) == :ok
  end

  test "a valid multi-series list with matching labels and names passes validation" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    assert Data.validate(data) == :ok
  end

  test "a single series may have a nil :name" do
    data = [%{name: nil, data: [%{label: "Jan", value: 10}]}]
    assert Data.validate(data) == :ok
  end

  test "a valid item may include an :attrs map" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}]
    assert Data.validate(data) == :ok
  end

  test "rejects an empty list" do
    assert {:error, reason} = Data.validate([])
    assert reason =~ "empty"
  end

  test "rejects a non-list" do
    assert {:error, reason} = Data.validate(%{})
    assert reason =~ "list"
  end

  test "rejects a series missing :name or :data" do
    assert {:error, reason} = Data.validate([%{data: [%{label: "Jan", value: 10}]}])
    assert reason =~ "invalid series"
  end

  test "rejects a non-map series element" do
    assert {:error, reason} = Data.validate([1, 2])
    assert reason =~ "invalid series"
  end

  test "rejects a series with an empty :data list" do
    assert {:error, reason} = Data.validate([%{name: "Sales", data: []}])
    assert reason =~ "must not be empty"
  end

  test "rejects an item missing :label" do
    data = [%{name: "Sales", data: [%{value: 10}]}]
    assert {:error, _reason} = Data.validate(data)
  end

  test "rejects an item with a non-numeric :value" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: "10"}]}]
    assert {:error, _reason} = Data.validate(data)
  end

  test "rejects an item with a negative :value" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: -1}]}]
    assert {:error, reason} = Data.validate(data)
    assert reason =~ "negative"
  end

  test "rejects mismatched labels across series" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Mar", value: 8}]}
    ]

    assert {:error, reason} = Data.validate(data)
    assert reason =~ "labels must match"
  end

  test "rejects mismatched label counts across series" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    assert {:error, reason} = Data.validate(data)
    assert reason =~ "labels must match"
  end

  test "rejects a nil :name when there are 2+ series" do
    data = [
      %{name: nil, data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    assert {:error, reason} = Data.validate(data)
    assert reason =~ "name is required"
  end
end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/data_test.exs`
Expected: FAIL — the current `Data.validate/1` validates the old flat shape, so most of these new tests either error out (trying to treat a series map as a data item) or don't get the new error messages.

- [x] **Step 3: Implement**

Replace the entire contents of `lib/plotto/data.ex`:

```elixir
defmodule Plotto.Data do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    with :ok <- validate_series(data),
         :ok <- validate_matching_labels(data),
         :ok <- validate_names(data) do
      :ok
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

  defp validate_series(series_list) do
    case Enum.find_value(series_list, &series_error/1) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  defp series_error(%{name: name, data: []}) when is_binary(name) or is_nil(name) do
    "series data must not be empty for series: #{inspect(name)}"
  end

  defp series_error(%{name: name, data: series_data})
       when (is_binary(name) or is_nil(name)) and is_list(series_data) do
    Enum.find_value(series_data, &item_error(&1, name))
  end

  defp series_error(series) do
    "invalid series, expected a map with :name (string or nil) and :data (list), " <>
      "got: #{inspect(series)}"
  end

  defp item_error(%{label: label, value: value}, name) when is_binary(label) and is_number(value) do
    if value < 0 do
      "value must not be negative, got: #{inspect(value)} for label #{inspect(label)} " <>
        "in series: #{inspect(name)}"
    else
      nil
    end
  end

  defp item_error(item, name) do
    "invalid data item, expected a map with :label (string) and :value (number), " <>
      "got: #{inspect(item)} in series: #{inspect(name)}"
  end

  defp validate_matching_labels([%{data: first_data} | rest]) do
    expected_labels = Enum.map(first_data, & &1.label)

    case Enum.find_value(rest, &label_mismatch_error(&1, expected_labels)) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  defp label_mismatch_error(%{name: name, data: series_data}, expected_labels) do
    labels = Enum.map(series_data, & &1.label)

    if labels == expected_labels do
      nil
    else
      "series labels must match, expected #{inspect(expected_labels)}, " <>
        "got #{inspect(labels)} for series: #{inspect(name)}"
    end
  end

  defp validate_names([_single_series]), do: :ok

  defp validate_names(series_list) do
    case Enum.find_value(series_list, &nil_name_error/1) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  defp nil_name_error(%{name: nil}), do: "series name is required when there are multiple series"
  defp nil_name_error(_series), do: nil
end
```

- [x] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/data_test.exs`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/plotto/data.ex test/plotto/data_test.exs
git commit -m "Rewrite Plotto.Data.validate/1 for multi-series data"
```

---

### Task 2: Remove `:name` from `Plotto.Options`

**Files:**
- Modify: `lib/plotto/options.ex`
- Test: `test/plotto/options_test.exs`

- [x] **Step 1: Write the failing tests**

Replace the entire contents of `test/plotto/options_test.exs`:

```elixir
defmodule Plotto.OptionsTest do
  use ExUnit.Case, async: true

  alias Plotto.Options

  test "fills in defaults when no opts given" do
    opts = Options.build([])
    assert opts.width == Plotto.Theme.default_width()
    assert opts.height == Plotto.Theme.default_height()
    assert opts.title == nil
    assert opts.colors == Plotto.Theme.default_colors()
  end

  test "overrides defaults with given opts" do
    opts = Options.build(width: 800, height: 500, title: "Sales", colors: ["#000000"])
    assert opts.width == 800
    assert opts.height == 500
    assert opts.title == "Sales"
    assert opts.colors == ["#000000"]
  end

  test "fills in :legend as nil by default" do
    opts = Options.build([])
    assert opts.legend == nil
  end

  test "overrides :legend when given" do
    opts = Options.build(legend: :top_right)
    assert opts.legend == :top_right
  end

  test "does not include a :name field" do
    opts = Options.build(name: "Sales")
    refute Map.has_key?(opts, :name)
  end

  test "validate/1 returns :ok when :legend is absent" do
    assert Options.validate([]) == :ok
  end

  test "validate/1 returns :ok for each of the four valid legend positions" do
    for position <- Plotto.Theme.legend_positions() do
      assert Options.validate(legend: position) == :ok
    end
  end

  test "validate/1 returns {:error, reason} for an invalid legend position" do
    assert Options.validate(legend: :middle) ==
             {:error, "invalid legend position, got: :middle"}
  end
end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/options_test.exs`
Expected: FAIL only for "does not include a :name field" (current `build/1` still sets `:name`).

- [x] **Step 3: Implement**

Replace the entire contents of `lib/plotto/options.ex`:

```elixir
defmodule Plotto.Options do
  @moduledoc false

  alias Plotto.Theme

  def build(opts) do
    %{
      width: Keyword.get(opts, :width, Theme.default_width()),
      height: Keyword.get(opts, :height, Theme.default_height()),
      title: Keyword.get(opts, :title),
      colors: Keyword.get(opts, :colors, Theme.default_colors()),
      legend: Keyword.get(opts, :legend)
    }
  end

  def validate(opts) do
    case Keyword.get(opts, :legend) do
      nil ->
        :ok

      position ->
        if position in Theme.legend_positions() do
          :ok
        else
          {:error, "invalid legend position, got: #{inspect(position)}"}
        end
    end
  end
end
```

- [x] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/options_test.exs`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/plotto/options.ex test/plotto/options_test.exs
git commit -m "Remove chart-level :name option from Plotto.Options"
```

---

### Task 3: Update `Plotto.BarChart`, `Plotto.LineChart`, and `Plotto.ex` for the new data shape

**Files:**
- Modify: `lib/plotto/bar_chart.ex` (full rewrite)
- Modify: `lib/plotto/line_chart.ex` (full rewrite)
- Modify: `lib/plotto.ex:11-19` (the `## Options` moduledoc section) and its doctests (lines 38, 57, 75, 105 — each `Plotto.BarChart.new!([%{label: "Jan", value: 10}], ...)` call)
- Test: `test/plotto/bar_chart_test.exs`, `test/plotto/line_chart_test.exs`

This task updates typespecs, moduledocs, and doctests for the new `[%{name:, data:}]` shape. It does **not** touch the renderers (Tasks 5-6) — so `doctest Plotto` (in `lib/plotto.ex`, which calls `Plotto.to_svg/1`/`Plotto.to_png/1`) will still FAIL after this task, since the renderers don't understand the new struct shape yet. Only verify `test/plotto/bar_chart_test.exs` and `test/plotto/line_chart_test.exs` pass at this checkpoint — defer full doctest verification (including `doctest Plotto`) to Task 7.

- [x] **Step 1: Write the failing tests**

Replace the entire contents of `test/plotto/bar_chart_test.exs`:

```elixir
defmodule Plotto.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart

  @valid_data [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "new/2 returns {:ok, chart} for valid data" do
    assert {:ok, %BarChart{data: @valid_data}} = BarChart.new(@valid_data)
  end

  test "new/2 applies default opts when none given" do
    {:ok, chart} = BarChart.new(@valid_data)
    assert chart.opts.width == Plotto.Theme.default_width()
  end

  test "new/2 returns {:error, reason} for invalid data" do
    assert {:error, _reason} = BarChart.new([])
  end

  test "new!/2 returns the chart struct for valid data" do
    assert %BarChart{} = BarChart.new!(@valid_data, title: "Sales")
  end

  test "new!/2 raises ArgumentError for invalid data" do
    assert_raise ArgumentError, fn -> BarChart.new!([]) end
  end

  test "new/2 returns {:error, reason} for an invalid legend position" do
    assert {:error, reason} = BarChart.new(@valid_data, legend: :middle)
    assert reason =~ "invalid legend position"
  end

  test "new!/2 raises ArgumentError for an invalid legend position" do
    assert_raise ArgumentError, fn -> BarChart.new!(@valid_data, legend: :middle) end
  end

  test "new/2 accepts a valid :legend position" do
    assert {:ok, chart} = BarChart.new(@valid_data, legend: :top_right)
    assert chart.opts.legend == :top_right
  end

  test "new/2 returns {:error, reason} for a nil series name with 2+ series" do
    data = [
      %{name: nil, data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    assert {:error, reason} = BarChart.new(data)
    assert reason =~ "name is required"
  end
end
```

Replace the entire contents of `test/plotto/line_chart_test.exs`:

```elixir
defmodule Plotto.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart

  @valid_data [%{name: "Trend", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "new/2 returns {:ok, chart} for valid data" do
    assert {:ok, %LineChart{data: @valid_data}} = LineChart.new(@valid_data)
  end

  test "new/2 returns {:error, reason} for invalid data" do
    assert {:error, _reason} = LineChart.new([])
  end

  test "new!/2 returns the chart struct for valid data" do
    assert %LineChart{} = LineChart.new!(@valid_data, title: "Trend")
  end

  test "new!/2 raises ArgumentError for invalid data" do
    assert_raise ArgumentError, fn -> LineChart.new!([]) end
  end

  test "new/2 returns {:error, reason} for an invalid legend position" do
    assert {:error, reason} = LineChart.new(@valid_data, legend: :middle)
    assert reason =~ "invalid legend position"
  end

  test "new!/2 raises ArgumentError for an invalid legend position" do
    assert_raise ArgumentError, fn -> LineChart.new!(@valid_data, legend: :middle) end
  end

  test "new/2 accepts a valid :legend position" do
    assert {:ok, chart} = LineChart.new(@valid_data, legend: :top_right)
    assert chart.opts.legend == :top_right
  end
end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs`
Expected: FAIL — `Options` no longer has `:name`, so `chart.opts.name` references would error, and current struct doctests reference the old shape (these test files don't reference `.name` anymore, so most failures here come from `Data.validate/1` behavior already changing in Task 1 — the "returns {:ok, chart}" tests should already pass from Task 1's work; the `:legend`-only tests should already pass too. The new "nil series name with 2+ series" test is the one guaranteed to fail before this task's `BarChart`/`LineChart` code changes, though those modules don't need code changes themselves — only doc/typespec changes. If everything already passes at Step 2, that's fine; proceed to Step 3 for the doc/typespec updates regardless, since those are this task's actual deliverable).

- [x] **Step 3: Implement**

Replace the entire contents of `lib/plotto/bar_chart.ex`:

```elixir
defmodule Plotto.BarChart do
  @moduledoc """
  A bar chart: one or more series, each rendered as a group of bars per category,
  bar height proportional to `:value`.

  Use a bar chart to compare values across categories — sales per month, votes per
  candidate, and similar "one or more numbers per category" data. With multiple
  series, each category shows one bar per series, grouped side by side and colored
  per series (see `:colors`); a legend (see `:legend`) can label each series.

  ## Example

      data = [
        %{
          name: "Sales",
          data: [
            %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
            %{label: "Feb", value: 25}
          ]
        }
      ]

      chart = Plotto.BarChart.new!(data, title: "Sales", colors: ["#4E79A7"])
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
  One data series: `:name` (required when there are 2+ series — see `new/2`) and its
  list of `t:data_item/0` points. All series in a chart must share identical,
  identically-ordered `:label`s across their `:data`.
  """
  @type series :: %{
          required(:name) => String.t() | nil,
          required(:data) => [data_item()]
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
          colors: [String.t()],
          legend: :top_left | :top_right | :bottom_left | :bottom_right | nil
        }

  @type t :: %__MODULE__{data: [series()], opts: options()}

  @doc """
  Builds a bar chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` is a list of `t:series/0` maps — one or more series, each with a `:name`
  and a list of `t:data_item/0` points. All series must have identical,
  identically-ordered `:label`s; `:name` may be `nil` only when there is exactly one
  series (2+ series must each have a non-nil `:name`, since it's shown in the
  legend).

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings, cycled **per series** — all
      bars within one series share the same color (`Theme.color(colors, series_index)`).
      Defaults to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.
    * `:legend` - optional legend position: `:top_left`, `:top_right`, `:bottom_left`,
      or `:bottom_right`. Renders one swatch+name row per series (using each series'
      `:name`), stacked vertically. Defaults to `nil` (no legend).

  ## Examples

      iex> {:ok, chart} = Plotto.BarChart.new([%{name: "Sales", data: [%{label: "Jan", value: 10}]}])
      iex> chart.data
      [%{name: "Sales", data: [%{label: "Jan", value: 10}]}]

      iex> {:ok, chart} =
      ...>   Plotto.BarChart.new(
      ...>     [%{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}],
      ...>     title: "Sales",
      ...>     colors: ["#000000"]
      ...>   )
      iex> {chart.opts.title, chart.opts.colors}
      {"Sales", ["#000000"]}

      iex> {:ok, chart} =
      ...>   Plotto.BarChart.new(
      ...>     [%{name: "Sales", data: [%{label: "Jan", value: 10}]}],
      ...>     legend: :top_right
      ...>   )
      iex> chart.opts.legend
      :top_right

      iex> Plotto.BarChart.new([%{name: "Sales", data: [%{label: "Jan", value: 10}]}], legend: :middle)
      {:error, "invalid legend position, got: :middle"}

      iex> Plotto.BarChart.new([])
      {:error, "data must not be empty"}

      iex> data = [
      ...>   %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      ...>   %{name: nil, data: [%{label: "Jan", value: 5}]}
      ...> ]
      iex> Plotto.BarChart.new(data)
      {:error, "series name is required when there are multiple series"}

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
```

Replace the entire contents of `lib/plotto/line_chart.ex`:

```elixir
defmodule Plotto.LineChart do
  @moduledoc """
  A line chart: a single line connecting one point per data item.

  Use a line chart to show a trend across ordered categories — a metric over time,
  for example. `data` uses the same multi-series shape as `Plotto.BarChart`, but
  today only the **first** series is drawn — full multi-series line rendering
  (multiple lines) is planned for a future release; extra series are currently
  accepted (so both chart types share the same data validation) but ignored when
  rendering, including in the legend.

  ## Example

      data = [
        %{
          name: "Trend",
          data: [
            %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
            %{label: "Feb", value: 25}
          ]
        }
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
  One data series: `:name` (required when there are 2+ series — see `new/2`) and its
  list of `t:data_item/0` points. All series in a chart must share identical,
  identically-ordered `:label`s across their `:data`. Only the first series is
  currently drawn — see the moduledoc.
  """
  @type series :: %{
          required(:name) => String.t() | nil,
          required(:data) => [data_item()]
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
          colors: [String.t()],
          legend: :top_left | :top_right | :bottom_left | :bottom_right | nil
        }

  @type t :: %__MODULE__{data: [series()], opts: options()}

  @doc """
  Builds a line chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` is a list of `t:series/0` maps — see the moduledoc: only the first series
  is drawn today, but the validation rules (matching labels, `:name` required for
  2+ series) apply the same as for `Plotto.BarChart`.

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings; only the first color is
      used, as the (first/only-rendered series') line's stroke color. Defaults to
      `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.
    * `:legend` - optional legend position: `:top_left`, `:top_right`, `:bottom_left`,
      or `:bottom_right`. Renders one row for the first series' `:name` only.
      Defaults to `nil` (no legend).

  ## Examples

      iex> {:ok, chart} = Plotto.LineChart.new([%{name: "Trend", data: [%{label: "Jan", value: 10}]}])
      iex> chart.data
      [%{name: "Trend", data: [%{label: "Jan", value: 10}]}]

      iex> {:ok, chart} =
      ...>   Plotto.LineChart.new(
      ...>     [%{name: "Trend", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}],
      ...>     title: "Trend",
      ...>     colors: ["#000000"]
      ...>   )
      iex> {chart.opts.title, chart.opts.colors}
      {"Trend", ["#000000"]}

      iex> {:ok, chart} =
      ...>   Plotto.LineChart.new(
      ...>     [%{name: "Trend", data: [%{label: "Jan", value: 10}]}],
      ...>     legend: :top_right
      ...>   )
      iex> chart.opts.legend
      :top_right

      iex> Plotto.LineChart.new([%{name: "Trend", data: [%{label: "Jan", value: 10}]}], legend: :middle)
      {:error, "invalid legend position, got: :middle"}

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

In `lib/plotto.ex`, replace the `## Options` section (lines 11-19):

```elixir
  ## Options

  Both `Plotto.BarChart` and `Plotto.LineChart` accept the same five options via
  `new/2`/`new!/2`: `:width`, `:height`, `:title`, `:colors`, `:legend`. See
  `Plotto.BarChart.new/2` (or `Plotto.LineChart.new/2`) for their exact defaults and
  shapes — line charts differ slightly in how `:colors` is used (only the first
  color is applied) and currently only render their first series (documented
  there). `:legend` renders one row per series (each series' own `:name`),
  positioned in one of the chart's four corners.
```

In `lib/plotto.ex`, every doctest that currently constructs a chart with
`Plotto.BarChart.new!([%{label: "Jan", value: 10}], ...)` must use the new series
shape instead: `Plotto.BarChart.new!([%{name: "Sales", data: [%{label: "Jan", value: 10}]}], ...)`.
There are four such doctests, in the docs for `to_svg/1`, `to_svg!/1`, `to_png/1`,
and `to_png!/1` — update the `chart = Plotto.BarChart.new!(...)` line in each to the
new shape, keeping everything else in those doctests unchanged.

Also update the moduledoc's top `## Example` code block (line 7, not an executed
doctest — no `iex>` prompt, so it won't fail tests if missed, but it'll be visibly
stale otherwise):

```elixir
chart = Plotto.BarChart.new!([%{name: "Sales", data: [%{label: "Jan", value: 10}]}], title: "Sales")
```

- [x] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs`
Expected: PASS

Do **not** run the full suite or `test/plotto_test.exs` expecting green yet — see this task's intro note. `doctest Plotto`'s examples all construct `Plotto.BarChart` charts, so that specific doctest group will pass once Task 5 (BarChart renderer) lands; `doctest Plotto.LineChart`'s own examples don't call `Plotto.to_svg/1` so they're unaffected either way. `test/plotto/svg/renderer_test.exs` and `test/plotto_test.exs`'s own (non-doctest) tests are untouched until Task 7 and will still fail.

- [x] **Step 5: Commit**

```bash
git add lib/plotto/bar_chart.ex lib/plotto/line_chart.ex lib/plotto.ex \
        test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs
git commit -m "Update BarChart/LineChart typespecs, moduledocs, and doctests for multi-series data"
```

---

### Task 4: Multi-entry legend in `Plotto.SVG.Renderer.Shared`

**Files:**
- Modify: `lib/plotto/svg/renderer/shared.ex:110-193` (replace `effective_margin/3`, `legend_elements/6`, and `draws_legend?/2` with new list-based versions)
- Test: `test/plotto/svg/renderer/shared_test.exs`

This replaces the single-entry legend contract from the prior feature with a
list-based one: `effective_margin/3` and the new `legend_elements/5` both take a
list of `{name, color}` entries (one per series) instead of a single `name`/`color`
pair, and both derive "how many rows will actually draw" via one shared private
helper (`drawable_entries/2`) so they can never disagree — this is the fix for
the "reserved but empty" bug class the spec calls out.

- [x] **Step 1: Write the failing tests**

In `test/plotto/svg/renderer/shared_test.exs`, replace the `describe "effective_margin/3"` and `describe "legend_elements/6"` blocks (the `svg_root/3`, `title_elements/2`, and `axis_elements/5` tests above them are unchanged, keep them as-is) with:

```elixir
  describe "effective_margin/3" do
    @margin Plotto.Theme.margin()
    @row_height Plotto.Theme.legend_row_height()

    test "returns the margin unchanged when legend is nil" do
      assert Shared.effective_margin(@margin, nil, [{"Sales", "#4E79A7"}]) == @margin
    end

    test "returns the margin unchanged when entries is empty" do
      assert Shared.effective_margin(@margin, :top_left, []) == @margin
    end

    test "returns the margin unchanged for a single nil-named entry (nothing to draw)" do
      assert Shared.effective_margin(@margin, :top_left, [{nil, "#4E79A7"}]) == @margin
    end

    test "adds legend_row_height * n to margin.top for :top_left/:top_right" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]

      for position <- [:top_left, :top_right] do
        result = Shared.effective_margin(@margin, position, entries)
        assert result.top == @margin.top + @row_height * 2
        assert result.bottom == @margin.bottom
      end
    end

    test "adds legend_row_height * n to margin.bottom for :bottom_left/:bottom_right" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}, {"Other", "#E15759"}]

      for position <- [:bottom_left, :bottom_right] do
        result = Shared.effective_margin(@margin, position, entries)
        assert result.bottom == @margin.bottom + @row_height * 3
        assert result.top == @margin.top
      end
    end
  end

  describe "legend_elements/5" do
    @margin Plotto.Theme.margin()

    test "returns [] when legend is nil" do
      assert Shared.legend_elements([{"Sales", "#4E79A7"}], nil, @margin, 600, 400) == []
    end

    test "returns [] when entries is empty" do
      assert Shared.legend_elements([], :top_left, @margin, 600, 400) == []
    end

    test "returns [] for a single nil-named entry (nothing to draw)" do
      assert Shared.legend_elements([{nil, "#4E79A7"}], :top_left, @margin, 600, 400) == []
    end

    test "returns [] for a legend atom outside the four valid positions (defensive)" do
      assert Shared.legend_elements([{"Sales", "#4E79A7"}], :middle, @margin, 600, 400) == []
    end

    test "returns one swatch+text pair for a single entry" do
      [swatch, text] = Shared.legend_elements([{"Sales", "#4E79A7"}], :top_right, @margin, 600, 400)

      assert swatch.tag == "rect"
      assert swatch.attrs["fill"] == "#4E79A7"
      assert text.tag == "text"
      assert text.attrs["text-anchor"] == "end"
      assert text.children == ["Sales"]
    end

    test "returns N swatch+text pairs for N entries" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}, {"Other", "#E15759"}]
      elements = Shared.legend_elements(entries, :top_left, @margin, 600, 400)

      assert length(elements) == 6
      texts = elements |> Enum.filter(&(&1.tag == "text")) |> Enum.map(& &1.children)
      assert texts == [["Sales"], ["Costs"], ["Other"]]
    end

    test "row 0 is topmost for both :top_* and :bottom_* positions" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]

      for position <- [:top_left, :bottom_left] do
        margin = Shared.effective_margin(@margin, position, entries)
        [row0_swatch, _row0_text, row1_swatch, _row1_text] =
          Shared.legend_elements(entries, position, margin, 600, 400)

        row0_y = elem(Float.parse(row0_swatch.attrs["y"]), 0)
        row1_y = elem(Float.parse(row1_swatch.attrs["y"]), 0)

        assert row0_y < row1_y
      end
    end

    test "bottom-position legend (N entries) does not overlap the x-axis tick labels" do
      entries = [{"Sales", "#4E79A7"}, {"Costs", "#F28E2B"}]
      margin = Shared.effective_margin(@margin, :bottom_left, entries)
      plot_width = 600 - margin.left - margin.right
      plot_height = 400 - margin.top - margin.bottom
      bands = Plotto.Axis.categorical_scale(["Jan", "Feb"], plot_width)

      axis = Shared.axis_elements(bands, margin, plot_width, plot_height, 10)

      max_tick_label_y =
        axis
        |> Enum.filter(&(&1.tag == "text"))
        |> Enum.map(&elem(Float.parse(&1.attrs["y"]), 0))
        |> Enum.max()

      min_swatch_y =
        entries
        |> then(&Shared.legend_elements(&1, :bottom_left, margin, 600, 400))
        |> Enum.filter(&(&1.tag == "rect"))
        |> Enum.map(&elem(Float.parse(&1.attrs["y"]), 0))
        |> Enum.min()

      assert min_swatch_y > max_tick_label_y
    end
  end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/shared_test.exs`
Expected: FAIL — `effective_margin/3`'s third argument is currently a single `name`, not a list, so these calls pass the wrong shape; `legend_elements/5` doesn't exist yet (current arity is 6, with a different signature).

- [x] **Step 3: Implement**

In `lib/plotto/svg/renderer/shared.ex`, replace lines 110-193 (from `def effective_margin` through the end of `defp draws_legend?/2`, i.e. everything after `format_tick/1` and before the module's final `end`):

```elixir
  def effective_margin(margin, legend, entries) do
    case length(drawable_entries(legend, entries)) do
      0 ->
        margin

      n ->
        case legend do
          position when position in [:top_left, :top_right] ->
            Map.update!(margin, :top, &(&1 + Theme.legend_row_height() * n))

          position when position in [:bottom_left, :bottom_right] ->
            Map.update!(margin, :bottom, &(&1 + Theme.legend_row_height() * n))
        end
    end
  end

  def legend_elements(entries, legend, margin, width, height) do
    drawable = drawable_entries(legend, entries)
    n = length(drawable)

    drawable
    |> Enum.with_index()
    |> Enum.flat_map(fn {{name, color}, i} ->
      legend_row(name, color, legend, margin, width, height, i, n)
    end)
  end

  # Shared by effective_margin/3 and legend_elements/5 so they can never disagree
  # on "how many rows will actually draw" — filters out nil-named entries (the only
  # way a single-series chart with `name: nil` reaches this point, since
  # Plotto.Data.validate/1 requires non-nil names whenever there are 2+ series) and
  # returns [] outright for an invalid/nil `legend` position.
  defp drawable_entries(legend, entries) when legend in @legend_positions do
    Enum.filter(entries, fn {name, _color} -> not is_nil(name) end)
  end

  defp drawable_entries(_legend, _entries), do: []

  # Generalizes the single-row formula from the prior legend design (n = 1, i = 0
  # reduces to `anchor - row_height / 2`, matching it exactly): row `i` (0-based,
  # `i = 0` topmost) of `n` total rows.
  #
  # Top: anchored to `margin.top` (already enlarged by effective_margin/3) — the
  # title lives at a fixed absolute y independent of margin, so the band above the
  # (enlarged) margin.top is genuinely empty.
  #
  # Bottom: anchored to the absolute `height`, NOT `margin.bottom` — the x-axis tick
  # labels are positioned relative to margin.bottom (see `x_label/2` above), so they
  # shift down as margin.bottom grows; the actual empty space is the last
  # `row_height * n` pixels of the canvas. Anchoring to margin.bottom instead would
  # place the legend on the tick labels' baseline (a real bug caught in the prior
  # single-entry legend design).
  #
  # `y_center(i) = anchor - row_height * (n - i - 0.5)` is strictly increasing in
  # `i` regardless of anchor, so row 0 is topmost-within-the-band for both :top_*
  # and :bottom_* positions — no special-casing needed per anchor.
  defp legend_row(name, color, legend, margin, width, height, i, n) do
    swatch_size = Theme.legend_swatch_size()
    gap = Theme.legend_gap()
    row_height = Theme.legend_row_height()
    font_size = Theme.font_size()

    anchor =
      case legend do
        position when position in [:top_left, :top_right] -> margin.top
        position when position in [:bottom_left, :bottom_right] -> height
      end

    y_center = anchor - row_height * (n - i - 0.5)

    {swatch_x, text_x, text_anchor} =
      case legend do
        position when position in [:top_left, :bottom_left] ->
          {margin.left, margin.left + swatch_size + gap, "start"}

        position when position in [:top_right, :bottom_right] ->
          {width - margin.right - swatch_size, width - margin.right - swatch_size - gap, "end"}
      end

    swatch =
      Element.new("rect", %{
        "x" => swatch_x,
        "y" => y_center - swatch_size / 2,
        "width" => swatch_size,
        "height" => swatch_size,
        "fill" => color
      })

    text =
      Element.new(
        "text",
        %{
          "x" => text_x,
          "y" => y_center + font_size / 2,
          "text-anchor" => text_anchor,
          "font-size" => font_size,
          "fill" => Theme.text_color()
        },
        [name]
      )

    [swatch, text]
  end
```

- [x] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/shared_test.exs`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer/shared.ex test/plotto/svg/renderer/shared_test.exs
git commit -m "Replace single-entry legend with multi-entry list-based contract in Renderer.Shared"
```

---

### Task 5: Grouped multi-series bars in `Plotto.SVG.Renderer.BarChart`

**Files:**
- Modify: `lib/plotto/svg/renderer/bar_chart.ex` (full rewrite)
- Test: `test/plotto/svg/renderer/bar_chart_test.exs` (full rewrite)

- [x] **Step 1: Write the failing tests**

Replace the entire contents of `test/plotto/svg/renderer/bar_chart_test.exs`:

```elixir
defmodule Plotto.SVG.Renderer.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart
  alias Plotto.SVG.Renderer.BarChart, as: Renderer

  @single_series [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "render/1 returns an <svg> root with one <rect> per data item for a single series" do
    chart = BarChart.new!(@single_series)
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    assert length(rects) == 2
  end

  test "all bars in a single series share one color (Theme.color(colors, 0))" do
    chart = BarChart.new!(@single_series)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    fills = rects |> Enum.map(& &1.attrs["fill"]) |> Enum.uniq()
    assert fills == [Plotto.Theme.color(Plotto.Theme.default_colors(), 0)]
  end

  test "per-item :attrs are merged onto the corresponding <rect>" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}]
    chart = BarChart.new!(data)
    svg = Renderer.render(chart)
    [rect] = Enum.filter(svg.children, &(&1.tag == "rect"))

    assert rect.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = BarChart.new!(@single_series, title: "Monthly")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Monthly"]} -> true
             _ -> false
           end)
  end

  test "includes a legend swatch and text when :legend is set and the series is named" do
    chart = BarChart.new!(@single_series, legend: :top_right)
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end

  test "does not include a legend when :legend is set but the (single) series has no name" do
    data = [%{name: nil, data: [%{label: "Jan", value: 10}]}]
    chart = BarChart.new!(data, legend: :top_right)
    svg = Renderer.render(chart)

    swatch_width = to_string(Plotto.Theme.legend_swatch_size())
    refute Enum.any?(svg.children, &(&1.tag == "rect" and &1.attrs["width"] == swatch_width))
  end

  test "a top legend pushes the y-axis line down by legend_row_height" do
    base_chart = BarChart.new!(@single_series)
    base_svg = Renderer.render(base_chart)
    [base_y_axis | _] = Enum.filter(base_svg.children, &(&1.tag == "line"))

    legend_chart = BarChart.new!(@single_series, legend: :top_left)
    legend_svg = Renderer.render(legend_chart)
    [legend_y_axis | _] = Enum.filter(legend_svg.children, &(&1.tag == "line"))

    base_y1 = elem(Float.parse(base_y_axis.attrs["y1"]), 0)
    legend_y1 = elem(Float.parse(legend_y_axis.attrs["y1"]), 0)

    assert legend_y1 == base_y1 + Plotto.Theme.legend_row_height()
  end

  test "renders n_series bars per category for a multi-series chart" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    chart = BarChart.new!(data)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    # 2 categories x 2 series = 4 bars
    assert length(rects) == 4
  end

  test "each series' bars share one color, distinct per series" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    colors = ["#111111", "#222222"]
    chart = BarChart.new!(data, colors: colors)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    fills = rects |> Enum.map(& &1.attrs["fill"]) |> Enum.uniq() |> Enum.sort()
    assert fills == Enum.sort(colors)
  end

  test "grouped bars within one category are flush against each other, no gap" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    chart = BarChart.new!(data, width: 600, height: 400)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    [first, second] =
      Enum.sort_by(rects, &elem(Float.parse(&1.attrs["x"]), 0))

    first_x = elem(Float.parse(first.attrs["x"]), 0)
    first_width = elem(Float.parse(first.attrs["width"]), 0)
    second_x = elem(Float.parse(second.attrs["x"]), 0)

    assert_in_delta first_x + first_width, second_x, 0.01
  end

  test "max_value spans all series, not just the first" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 90}]}
    ]

    chart = BarChart.new!(data, height: 400)
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    heights = rects |> Enum.map(&elem(Float.parse(&1.attrs["height"]), 0)) |> Enum.sort()
    assert Enum.at(heights, 1) > Enum.at(heights, 0) * 2
  end

  test "renders a legend row per series, in series order" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]}
    ]

    chart = BarChart.new!(data, legend: :top_left)
    svg = Renderer.render(chart)

    texts =
      svg.children
      |> Enum.filter(&(&1.tag == "text"))
      |> Enum.filter(&(&1.children in [["Sales"], ["Costs"]]))

    assert length(texts) == 2
    [sales_text] = Enum.filter(texts, &(&1.children == ["Sales"]))
    [costs_text] = Enum.filter(texts, &(&1.children == ["Costs"]))

    sales_y = elem(Float.parse(sales_text.attrs["y"]), 0)
    costs_y = elem(Float.parse(costs_text.attrs["y"]), 0)

    assert sales_y < costs_y
  end

  test ":bottom_right legend renders correctly with a realistic multi-series, multi-category chart" do
    data = [
      %{
        name: "Sales",
        data: [
          %{label: "Jan", value: 10},
          %{label: "Feb", value: 25},
          %{label: "Mar", value: 18},
          %{label: "Apr", value: 30}
        ]
      },
      %{
        name: "Costs",
        data: [
          %{label: "Jan", value: 5},
          %{label: "Feb", value: 8},
          %{label: "Mar", value: 6},
          %{label: "Apr", value: 9}
        ]
      }
    ]

    colors = ["#111111", "#222222"]
    chart = BarChart.new!(data, legend: :bottom_right, colors: colors)
    svg = Renderer.render(chart)

    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    # 4 categories x 2 series = 8 bars, + 2 legend swatches
    assert length(rects) == 10

    swatch_width = to_string(Plotto.Theme.legend_swatch_size())
    swatches = Enum.filter(rects, &(&1.attrs["width"] == swatch_width))
    assert length(swatches) == 2

    for expected_name <- ["Sales", "Costs"] do
      assert Enum.any?(svg.children, fn
               %{tag: "text", children: [^expected_name]} = text -> text.attrs["text-anchor"] == "end"
               _ -> false
             end)
    end
  end
end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/bar_chart_test.exs`
Expected: FAIL — the current renderer expects flat `data`, not a list of series.

- [x] **Step 3: Implement**

Replace the entire contents of `lib/plotto/svg/renderer/bar_chart.ex`:

```elixir
defmodule Plotto.SVG.Renderer.BarChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.BarChart{data: data, opts: opts}) do
    entries =
      data
      |> Enum.with_index()
      |> Enum.map(fn {series, index} -> {series.name, Theme.color(opts.colors, index)} end)

    margin = Shared.effective_margin(Theme.margin(), opts.legend, entries)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = data |> List.first() |> Map.fetch!(:data) |> Enum.map(& &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = data |> Enum.flat_map(& &1.data) |> Enum.map(& &1.value) |> Enum.max()
    n_series = length(data)

    bars =
      data
      |> Enum.with_index()
      |> Enum.flat_map(fn {series, series_index} ->
        color = Theme.color(opts.colors, series_index)

        series.data
        |> Enum.zip(bands)
        |> Enum.map(&build_bar(&1, margin, plot_height, max_value, color, series_index, n_series))
      end)

    legend = Shared.legend_elements(entries, opts.legend, margin, opts.width, opts.height)

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        bars ++ Shared.title_elements(opts.title, opts.width) ++ legend

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp build_bar({item, band}, margin, plot_height, max_value, color, series_index, n_series) do
    inner_width = band.band_width * 0.8
    inner_x = margin.left + band.band_x + band.band_width * 0.1
    sub_width = inner_width / n_series
    bar_x = inner_x + series_index * sub_width

    top_y = margin.top + Axis.linear_scale(item.value, max_value, plot_height)
    bar_height = plot_height - Axis.linear_scale(item.value, max_value, plot_height)

    attrs =
      %{
        "x" => bar_x,
        "y" => top_y,
        "width" => sub_width,
        "height" => bar_height,
        "fill" => color
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    Element.new("rect", attrs)
  end
end
```

Note: for `n_series = 1`, `sub_width == band.band_width * 0.8` and `bar_x == inner_x` — identical to today's single-series geometry, so single-series bar *positions* are pixel-identical to before (only the *color* changes, per Task 3's design).

- [x] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/bar_chart_test.exs`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer/bar_chart.ex test/plotto/svg/renderer/bar_chart_test.exs
git commit -m "Render grouped multi-series bars, colored per series, in Plotto.SVG.Renderer.BarChart"
```

---

### Task 6: Phase-1 compatibility in `Plotto.SVG.Renderer.LineChart`

**Files:**
- Modify: `lib/plotto/svg/renderer/line_chart.ex:8-45` (the `render/1` function body)
- Test: `test/plotto/svg/renderer/line_chart_test.exs` (full rewrite)

- [x] **Step 1: Write the failing tests**

Replace the entire contents of `test/plotto/svg/renderer/line_chart_test.exs`:

```elixir
defmodule Plotto.SVG.Renderer.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart
  alias Plotto.SVG.Renderer.LineChart, as: Renderer

  @single_series [%{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "render/1 returns an <svg> root with a single <polyline>" do
    chart = LineChart.new!(@single_series)
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    polylines = Enum.filter(svg.children, &(&1.tag == "polyline"))
    assert length(polylines) == 1
  end

  test "the polyline has one x,y coordinate pair per data item" do
    chart = LineChart.new!(@single_series)
    svg = Renderer.render(chart)
    [polyline] = Enum.filter(svg.children, &(&1.tag == "polyline"))

    points = String.split(polyline.attrs["points"], " ")
    assert length(points) == 2
  end

  test "renders one <circle> per data item" do
    chart = LineChart.new!(@single_series)
    svg = Renderer.render(chart)
    circles = Enum.filter(svg.children, &(&1.tag == "circle"))
    assert length(circles) == 2
  end

  test "per-item :attrs are merged onto the corresponding <circle>" do
    data = [%{name: "Revenue", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}]
    chart = LineChart.new!(data)
    svg = Renderer.render(chart)
    [circle] = Enum.filter(svg.children, &(&1.tag == "circle"))

    assert circle.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = LineChart.new!(@single_series, title: "Trend")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Trend"]} -> true
             _ -> false
           end)
  end

  test "includes a legend swatch and text when :legend is set and the series is named" do
    chart = LineChart.new!(@single_series, legend: :bottom_left)
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Revenue"]} -> true
             _ -> false
           end)
  end

  test "does not include a legend when :legend is set but the series has no name" do
    data = [%{name: nil, data: [%{label: "Jan", value: 10}]}]
    chart = LineChart.new!(data, legend: :bottom_left)
    svg = Renderer.render(chart)

    swatch_width = to_string(Plotto.Theme.legend_swatch_size())
    refute Enum.any?(svg.children, &(&1.tag == "rect" and &1.attrs["width"] == swatch_width))
  end

  test "a bottom legend pushes the plot's bottom edge up by legend_row_height" do
    base_chart = LineChart.new!(@single_series)
    base_svg = Renderer.render(base_chart)
    [_y_axis, base_x_axis | _] = Enum.filter(base_svg.children, &(&1.tag == "line"))

    legend_chart = LineChart.new!(@single_series, legend: :bottom_right)
    legend_svg = Renderer.render(legend_chart)
    [_y_axis, legend_x_axis | _] = Enum.filter(legend_svg.children, &(&1.tag == "line"))

    base_y2 = elem(Float.parse(base_x_axis.attrs["y2"]), 0)
    legend_y2 = elem(Float.parse(legend_x_axis.attrs["y2"]), 0)

    assert legend_y2 == base_y2 - Plotto.Theme.legend_row_height()
  end

  test "a multi-series chart still renders (only the first series' line/points, no crash)" do
    data = [
      %{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    chart = LineChart.new!(data)
    svg = Renderer.render(chart)

    assert length(Enum.filter(svg.children, &(&1.tag == "polyline"))) == 1
    assert length(Enum.filter(svg.children, &(&1.tag == "circle"))) == 2
  end

  test "a multi-series chart with :legend set renders exactly one legend row (the first series')" do
    data = [
      %{name: "Revenue", data: [%{label: "Jan", value: 10}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}]},
      %{name: "Other", data: [%{label: "Jan", value: 2}]}
    ]

    chart = LineChart.new!(data, legend: :top_right)
    svg = Renderer.render(chart)

    texts =
      svg.children
      |> Enum.filter(&(&1.tag == "text"))
      |> Enum.filter(&(&1.children in [["Revenue"], ["Costs"], ["Other"]]))

    assert length(texts) == 1
    assert hd(texts).children == ["Revenue"]
  end
end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/line_chart_test.exs`
Expected: FAIL — the current renderer expects flat `data`, not a list of series.

- [x] **Step 3: Implement**

Replace `lib/plotto/svg/renderer/line_chart.ex:8-45` (the whole `render/1` function; leave `build_polyline/2`, `fmt/1`, and `build_point_circle/2` below it unchanged):

```elixir
  def render(%Plotto.LineChart{data: data, opts: opts}) do
    %{name: name, data: series_data} = List.first(data)
    color = Theme.color(opts.colors, 0)
    entries = [{name, color}]

    margin = Shared.effective_margin(Theme.margin(), opts.legend, entries)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = Enum.map(series_data, & &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = series_data |> Enum.map(& &1.value) |> Enum.max()

    points =
      series_data
      |> Enum.zip(bands)
      |> Enum.map(fn {item, band} ->
        x = margin.left + band.x
        y = margin.top + Axis.linear_scale(item.value, max_value, plot_height)
        {item, x, y}
      end)

    legend = Shared.legend_elements(entries, opts.legend, margin, opts.width, opts.height)

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        [build_polyline(points, color)] ++
        Enum.map(points, &build_point_circle(&1, color)) ++
        Shared.title_elements(opts.title, opts.width) ++
        legend

    Shared.svg_root(opts.width, opts.height, children)
  end
```

- [x] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/line_chart_test.exs`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer/line_chart.ex test/plotto/svg/renderer/line_chart_test.exs
git commit -m "Update Plotto.SVG.Renderer.LineChart for multi-series data (Phase 1: first series only)"
```

---

### Task 7: Rewrite end-to-end tests

**Files:**
- Modify: `test/plotto_test.exs` (full rewrite)
- Modify: `test/plotto/svg/renderer_test.exs` (data literal update only)

This is the task where the whole suite (including `doctest Plotto`, which depends on
the renderers from Task 5 for `BarChart` examples) should return to green.

`test/plotto/svg/renderer_test.exs` is a separate, easy-to-miss file — it's the
`Plotto.SVG.Renderer` dispatch test (distinct from `test/plotto/svg/renderer/bar_chart_test.exs`
and `line_chart_test.exs`, which Tasks 5-6 already updated). It still uses the old
flat data shape and will raise `ArgumentError` once Task 1 lands, all the way
through this task, unless fixed here. Update it first:

In `test/plotto/svg/renderer_test.exs`, change:

```elixir
  test "dispatches BarChart to the bar chart renderer" do
    chart = BarChart.new!([%{label: "Jan", value: 10}])
```

to:

```elixir
  test "dispatches BarChart to the bar chart renderer" do
    chart = BarChart.new!([%{name: "Sales", data: [%{label: "Jan", value: 10}]}])
```

and change:

```elixir
  test "dispatches LineChart to the line chart renderer" do
    chart = LineChart.new!([%{label: "Jan", value: 10}])
```

to:

```elixir
  test "dispatches LineChart to the line chart renderer" do
    chart = LineChart.new!([%{name: "Trend", data: [%{label: "Jan", value: 10}]}])
```

- [x] **Step 1: Write the failing tests**

Replace the entire contents of `test/plotto_test.exs`:

```elixir
defmodule PlottoTest do
  use ExUnit.Case, async: true

  doctest Plotto
  doctest Plotto.BarChart
  doctest Plotto.LineChart

  alias Plotto.{BarChart, LineChart}

  @single_series [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]

  test "to_svg/1 returns {:ok, svg_string} for a bar chart" do
    chart = BarChart.new!(@single_series)
    assert {:ok, svg} = Plotto.to_svg(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<rect"
  end

  test "to_svg!/1 returns the svg string directly for a line chart" do
    chart = LineChart.new!(@single_series)
    svg = Plotto.to_svg!(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<polyline"
  end

  test "per-item attrs pass through end to end into the SVG output" do
    data = [%{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}]
    chart = BarChart.new!(data)

    svg = Plotto.to_svg!(chart)
    assert svg =~ ~s(phx-click="select")
  end

  test "labels with special characters are escaped end to end" do
    data = [%{name: "Sales", data: [%{label: "<script>", value: 10}]}]
    chart = BarChart.new!(data)
    svg = Plotto.to_svg!(chart)
    refute svg =~ "<script>"
    assert svg =~ "&lt;script&gt;"
  end

  test "a bar chart with a legend renders the series name end to end in SVG" do
    chart = BarChart.new!(@single_series, legend: :top_right)

    svg = Plotto.to_svg!(chart)
    assert svg =~ "Sales"
  end

  test "all bars in a single-series chart share one color end to end" do
    data = [%{name: "Sales", data: for(i <- 0..6, do: %{label: "Item#{i}", value: i + 1})}]

    chart = BarChart.new!(data)
    svg = Plotto.to_svg!(chart)

    fills =
      Regex.scan(~r/<rect fill="(#[0-9A-Fa-f]{6})"/, svg)
      |> Enum.map(fn [_, fill] -> fill end)

    assert Enum.uniq(fills) == [Plotto.Theme.color(Plotto.Theme.default_colors(), 0)]
  end

  test "each series gets a distinct color end to end for a multi-series bar chart" do
    data = [
      %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
      %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
    ]

    chart = BarChart.new!(data, colors: ["#111111", "#222222"])
    svg = Plotto.to_svg!(chart)

    assert svg =~ "#111111"
    assert svg =~ "#222222"
  end

  test "custom :width and :height thread through new!/2 into the rendered SVG" do
    chart = BarChart.new!(@single_series, width: 800, height: 500)

    svg = Plotto.to_svg!(chart)

    assert svg =~ ~s(width="800")
    assert svg =~ ~s(height="500")
    assert svg =~ ~s(viewBox="0 0 800 500")
  end

  test "to_svg/1 returns {:error, reason} for a value that isn't a supported chart" do
    assert {:error, reason} = Plotto.to_svg(%{not: "a chart"})
    assert is_binary(reason)
  end

  test "to_svg!/1 raises ArgumentError for a value that isn't a supported chart" do
    assert_raise ArgumentError, fn -> Plotto.to_svg!(%{not: "a chart"}) end
  end

  describe "to_png/1 and to_png!/1" do
    @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

    test "to_png/1 returns {:ok, png_binary} for a bar chart, at final (non-supersampled) dimensions" do
      chart = BarChart.new!(@single_series, width: 100, height: 80)

      assert {:ok, png} = Plotto.to_png(chart)

      assert binary_part(png, 0, 8) == @png_signature
      <<@png_signature, _length::32, "IHDR", width::32, height::32, _rest::binary>> = png
      assert width == 100
      assert height == 80
    end

    test "to_png!/1 returns the png binary directly for a line chart" do
      chart = LineChart.new!(@single_series)
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

  describe "to_png!/1 end-to-end" do
    test "a bar chart with a title and custom colors renders without error" do
      data = [
        %{
          name: "Sales",
          data: [
            %{label: "Jan", value: 10},
            %{label: "Feb", value: 25},
            %{label: "Mar", value: 18},
            %{label: "Apr", value: 30}
          ]
        }
      ]

      chart = BarChart.new!(data, title: "Sales", colors: ["#4E79A7"])
      png = Plotto.to_png!(chart)

      assert byte_size(png) > 0
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a chart with a label containing accented characters renders without error" do
      data = [%{name: "Sales", data: [%{label: "Niño", value: 10}, %{label: "café", value: 15}]}]
      chart = BarChart.new!(data, title: "Tendencias")

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a bar chart with a legend renders without error" do
      chart = BarChart.new!(@single_series, legend: :bottom_left)

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a line chart with a legend renders without error" do
      data = [%{name: "Revenue", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}]
      chart = LineChart.new!(data, legend: :top_left)

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a multi-series bar chart with a legend renders without error" do
      data = [
        %{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]},
        %{name: "Costs", data: [%{label: "Jan", value: 5}, %{label: "Feb", value: 8}]}
      ]

      chart = BarChart.new!(data, title: "Sales vs Costs", legend: :top_right)
      png = Plotto.to_png!(chart)

      assert binary_part(png, 0, 8) == @png_signature
    end
  end
end
```

- [x] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto_test.exs`
Expected: at this point, given Tasks 1-6 and this task's Step 0 (`renderer_test.exs`) are already done, this should mostly PASS already — this task is primarily about catching any remaining old-shape references and adding the new multi-series coverage. If something fails unexpectedly here, first check whether it's a real gap in Tasks 1-6's logic, or another old-flat-shape reference lurking in a test file the plan didn't anticipate (as `renderer_test.exs` turned out to be) — run `grep -rn "label:.*value:" test/` and check every hit uses the new `%{name:, data: [...]}` shape before assuming the renderer/validation code itself is wrong.

- [x] **Step 3: Run tests to verify they pass**

Run: `mix test test/plotto_test.exs`
Expected: PASS

- [x] **Step 4: Run the full suite**

Run: `mix test`
Expected: PASS, all green — this is the first point in the plan where the whole suite should be green again.

- [x] **Step 5: Commit**

```bash
git add test/plotto_test.exs test/plotto/svg/renderer_test.exs
git commit -m "Rewrite end-to-end tests for multi-series data"
```

---

### Task 8: Update examples

**Files:**
- Modify: `examples/bar_chart.exs` (becomes the multi-series showcase: Sales vs Costs)
- Modify: `examples/line_chart.exs` (single series, new shape — Phase 2 will make this multi-series)
- Regenerate: `examples/bar_chart.svg`, `examples/bar_chart.png`, `examples/line_chart.svg`, `examples/line_chart.png`

- [x] **Step 1: Update `examples/bar_chart.exs`**

Replace its entire contents:

```elixir
data = [
  %{
    name: "Sales",
    data: [
      %{label: "Jan", value: 42},
      %{label: "Feb", value: 58},
      %{label: "Mar", value: 33},
      %{label: "Apr", value: 71},
      %{label: "May", value: 65},
      %{label: "Jun", value: 90}
    ]
  },
  %{
    name: "Costs",
    data: [
      %{label: "Jan", value: 20},
      %{label: "Feb", value: 25},
      %{label: "Mar", value: 18},
      %{label: "Apr", value: 30},
      %{label: "May", value: 28},
      %{label: "Jun", value: 35}
    ]
  }
]

chart = Plotto.BarChart.new!(data, title: "Monthly Sales vs Costs", legend: :top_right)
svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "bar_chart.svg"), svg)
File.write!(Path.join(__DIR__, "bar_chart.png"), png)
```

- [x] **Step 2: Update `examples/line_chart.exs`**

Replace its entire contents:

```elixir
data = [
  %{
    name: "Sales",
    data: [
      %{label: "Jan", value: 42},
      %{label: "Feb", value: 58},
      %{label: "Mar", value: 33},
      %{label: "Apr", value: 71},
      %{label: "May", value: 65},
      %{label: "Jun", value: 90}
    ]
  }
]

chart = Plotto.LineChart.new!(data, title: "Monthly Sales", legend: :bottom_left)
svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "line_chart.svg"), svg)
File.write!(Path.join(__DIR__, "line_chart.png"), png)
```

- [x] **Step 3: Regenerate the output files**

Run: `mix run examples/bar_chart.exs && mix run examples/line_chart.exs`
Expected: no errors; all four output files rewritten.

- [x] **Step 4: Visually spot-check both outputs**

Open `examples/bar_chart.png` and confirm: two bars per month (Sales and Costs, side by side with no gap between them, different colors), a legend in the top-right with two rows ("Sales", "Costs"), no overlap with the title.

Open `examples/line_chart.png` and confirm it looks the same as before (single line, legend bottom-left) — this example didn't change behaviorally, only its data shape.

- [x] **Step 5: Commit**

```bash
git add examples/bar_chart.exs examples/bar_chart.svg examples/bar_chart.png \
        examples/line_chart.exs examples/line_chart.svg examples/line_chart.png
git commit -m "Update examples for multi-series bar chart data shape"
```

---

### Task 9: Update README.md

**Files:**
- Modify: `README.md`

- [x] **Step 1: Update the intro and Usage section**

In `README.md`, replace the paragraph mentioning `:title`, `:name`, and `:legend`:

```markdown
Charts can also show an optional title and a legend (one color swatch + name row per series), positioned in any of the four corners — see `:title` and `:legend` in `Plotto.BarChart` or `Plotto.LineChart`.
```

Replace the `## Usage` code block:

```elixir
chart =
  Plotto.BarChart.new!(
    [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}],
    title: "Sales"
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)
```

- [x] **Step 2: Update the `## Examples` section**

Replace the bar chart code block with `examples/bar_chart.exs`'s new multi-series content (from Task 8, Step 1), and update its intro sentence to mention two series:

```markdown
[examples/bar_chart.exs](examples/bar_chart.exs) generates the chart below (`mix run examples/bar_chart.exs`), with two series ("Sales" and "Costs") grouped per month and a top-right legend:
```

Replace the line chart code block with `examples/line_chart.exs`'s new content (from Task 8, Step 2) — its intro sentence doesn't need wording changes, only the code block:

```elixir
data = [
  %{
    name: "Sales",
    data: [
      %{label: "Jan", value: 42},
      %{label: "Feb", value: 58},
      %{label: "Mar", value: 33},
      %{label: "Apr", value: 71},
      %{label: "May", value: 65},
      %{label: "Jun", value: 90}
    ]
  }
]

chart = Plotto.LineChart.new!(data, title: "Monthly Sales", legend: :bottom_left)
svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "line_chart.svg"), svg)
File.write!(Path.join(__DIR__, "line_chart.png"), png)
```

- [x] **Step 3: Verify ExDoc still builds cleanly**

Run: `mix docs`
Expected: succeeds with no warnings.

- [x] **Step 4: Commit**

```bash
git add README.md
git commit -m "Update README for multi-series bar chart data shape"
```

---

### Task 10: Final full-suite check

**Files:** none (verification only)

- [x] **Step 1: Run the full test suite**

Run: `mix test`
Expected: PASS, all tests green.

- [x] **Step 2: Run the formatter check**

Run: `mix format --check-formatted`
Expected: no output. If it reports unformatted files, run `mix format` and re-check.

- [x] **Step 3: Commit formatting fixes if any were needed**

```bash
git add -u
git commit -m "Apply mix format"
```

(Skip this step entirely if Step 2 reported nothing to format.)

- [x] **Step 4: Run `mix docs` one more time**

Run: `mix docs`
Expected: succeeds with no warnings.
