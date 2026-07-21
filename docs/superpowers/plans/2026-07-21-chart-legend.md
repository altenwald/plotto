# Optional Chart Legend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, single-entry legend (color swatch + series name) to `Plotto.BarChart` and `Plotto.LineChart`, positionable in one of the four chart corners.

**Architecture:** Two new chart options (`:name`, `:legend`) flow through the existing `Plotto.Options`/`Plotto.Chart.Builder` pipeline (gaining a new `Options.validate/1` step), then a new `Plotto.SVG.Renderer.Shared.legend_elements/6` helper (plus an `effective_margin/3` helper that reserves layout space) is wired into both SVG renderers. PNG output needs no code changes — it already draws generically off the same `Plotto.SVG.Element` tree.

**Tech Stack:** Elixir, ExUnit. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-21-chart-legend-design.md`

---

## Before you start

`examples/bar_chart.exs` currently has an **uncommitted** local change (unrelated to this plan — it adds `to_png!`/PNG-file-writing lines that predate this work). Task 10 edits this same file. Do not discard that existing uncommitted diff, and do not fold it silently into a legend-feature commit — when you get to Task 10's commit step, run `git diff examples/bar_chart.exs` first and flag the pre-existing PNG-export lines to the human before committing, in case they want that committed separately.

`examples/line_chart.exs` (and its `.svg`/`.png` outputs) are also already present in the working tree as **untracked** files, wholly separate from this plan — Task 10 Step 1's `git status --porcelain examples/` will surface this too; it's expected, not a sign something went wrong.

Run `mix test` once before starting to confirm the suite is green on a clean baseline.

---

### Task 1: Theme constants for the legend

**Files:**
- Modify: `lib/plotto/theme.ex:17-27`
- Test: `test/plotto/theme_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto/theme_test.exs`:

```elixir
  test "legend_positions/0 returns the four valid corner atoms" do
    assert Theme.legend_positions() == [:top_left, :top_right, :bottom_left, :bottom_right]
  end

  test "legend_swatch_size/0, legend_gap/0, and legend_row_height/0 return positive integers" do
    assert Theme.legend_swatch_size() > 0
    assert Theme.legend_gap() > 0
    assert Theme.legend_row_height() > 0
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/theme_test.exs`
Expected: FAIL with `UndefinedFunctionError` for `Theme.legend_positions/0` (and friends).

- [ ] **Step 3: Implement**

In `lib/plotto/theme.ex`, replace lines 17-27:

```elixir
  @font_size 12
  @title_font_size 18
  @legend_positions [:top_left, :top_right, :bottom_left, :bottom_right]
  @legend_swatch_size 10
  @legend_gap 6
  @legend_row_height 20

  def default_colors, do: @default_colors
  def default_width, do: @default_width
  def default_height, do: @default_height
  def margin, do: @margin
  def axis_color, do: @axis_color
  def text_color, do: @text_color
  def font_size, do: @font_size
  def title_font_size, do: @title_font_size
  def legend_positions, do: @legend_positions
  def legend_swatch_size, do: @legend_swatch_size
  def legend_gap, do: @legend_gap
  def legend_row_height, do: @legend_row_height
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/theme_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/theme.ex test/plotto/theme_test.exs
git commit -m "Add legend layout constants to Plotto.Theme"
```

---

### Task 2: `:name`/`:legend` options and validation

**Files:**
- Modify: `lib/plotto/options.ex`
- Test: `test/plotto/options_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto/options_test.exs`:

```elixir
  test "fills in :name and :legend as nil by default" do
    opts = Options.build([])
    assert opts.name == nil
    assert opts.legend == nil
  end

  test "overrides :name and :legend when given" do
    opts = Options.build(name: "Sales", legend: :top_right)
    assert opts.name == "Sales"
    assert opts.legend == :top_right
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/options_test.exs`
Expected: FAIL — `opts.name`/`opts.legend` are `KeyError` (keys don't exist on the map yet), and `Options.validate/1` is `UndefinedFunctionError`.

- [ ] **Step 3: Implement**

Replace the whole body of `lib/plotto/options.ex`:

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
      name: Keyword.get(opts, :name),
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/options_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/options.ex test/plotto/options_test.exs
git commit -m "Add :name/:legend options and legend position validation"
```

---

### Task 3: Wire validation into `Plotto.Chart.Builder`

**Files:**
- Modify: `lib/plotto/chart/builder.ex:6-11`
- Test: `test/plotto/bar_chart_test.exs`, `test/plotto/line_chart_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto/bar_chart_test.exs`:

```elixir
  test "new/2 returns {:error, reason} for an invalid legend position" do
    assert {:error, reason} = BarChart.new(@valid_data, legend: :middle)
    assert reason =~ "invalid legend position"
  end

  test "new!/2 raises ArgumentError for an invalid legend position" do
    assert_raise ArgumentError, fn -> BarChart.new!(@valid_data, legend: :middle) end
  end

  test "new/2 accepts a valid :legend position together with :name" do
    assert {:ok, chart} = BarChart.new(@valid_data, name: "Sales", legend: :top_right)
    assert chart.opts.name == "Sales"
    assert chart.opts.legend == :top_right
  end
```

Add the same three tests to `test/plotto/line_chart_test.exs` (swap `BarChart`/`@valid_data` references for `LineChart`'s existing `@valid_data`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs`
Expected: FAIL — invalid `:legend` currently passes through silently (no error), so the first two new tests per file fail.

- [ ] **Step 3: Implement**

Replace `lib/plotto/chart/builder.ex:6-11`:

```elixir
  def new(module, data, opts) do
    with :ok <- Data.validate(data),
         :ok <- Options.validate(opts) do
      {:ok, struct(module, data: data, opts: Options.build(opts))}
    end
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/chart/builder.ex test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs
git commit -m "Validate :legend option in Plotto.Chart.Builder.new/3"
```

---

### Task 4: `Plotto.SVG.Renderer.Shared` — margin reservation and legend elements

**Files:**
- Modify: `lib/plotto/svg/renderer/shared.ex`
- Test: `test/plotto/svg/renderer/shared_test.exs`

This is the core layout/rendering logic, shared by both chart renderers.

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto/svg/renderer/shared_test.exs`:

```elixir
  describe "effective_margin/3" do
    test "returns the margin unchanged when legend is nil" do
      margin = Plotto.Theme.margin()
      assert Shared.effective_margin(margin, nil, "Sales") == margin
    end

    test "returns the margin unchanged when name is nil, even with a legend position" do
      margin = Plotto.Theme.margin()
      assert Shared.effective_margin(margin, :top_left, nil) == margin
    end

    test "adds legend_row_height to margin.top for :top_left/:top_right" do
      margin = Plotto.Theme.margin()
      row_height = Plotto.Theme.legend_row_height()

      for position <- [:top_left, :top_right] do
        result = Shared.effective_margin(margin, position, "Sales")
        assert result.top == margin.top + row_height
        assert result.bottom == margin.bottom
      end
    end

    test "adds legend_row_height to margin.bottom for :bottom_left/:bottom_right" do
      margin = Plotto.Theme.margin()
      row_height = Plotto.Theme.legend_row_height()

      for position <- [:bottom_left, :bottom_right] do
        result = Shared.effective_margin(margin, position, "Sales")
        assert result.bottom == margin.bottom + row_height
        assert result.top == margin.top
      end
    end
  end

  describe "legend_elements/6" do
    @margin Plotto.Theme.margin()

    test "returns [] when name is nil" do
      assert Shared.legend_elements(nil, :top_left, "#000000", @margin, 600, 400) == []
    end

    test "returns [] when legend is nil" do
      assert Shared.legend_elements("Sales", nil, "#000000", @margin, 600, 400) == []
    end

    test "returns a swatch <rect> and a <text> for a left position" do
      [swatch, text] = Shared.legend_elements("Sales", :top_left, "#4E79A7", @margin, 600, 400)

      assert swatch.tag == "rect"
      assert swatch.attrs["fill"] == "#4E79A7"
      assert text.tag == "text"
      assert text.attrs["text-anchor"] == "start"
      assert text.children == ["Sales"]
    end

    test "returns a swatch <rect> and a <text> for a right position" do
      [swatch, text] = Shared.legend_elements("Sales", :top_right, "#4E79A7", @margin, 600, 400)

      assert swatch.tag == "rect"
      assert text.attrs["text-anchor"] == "end"
    end

    # Note: use Float.parse/1, not String.to_float/1, to read numeric attrs back out —
    # Plotto.SVG.Element.new/3's format_value/1 only appends a decimal point to genuine
    # floats, so integer-valued attrs (e.g. margin.top itself) format as plain integer
    # strings like "40", which String.to_float/1 rejects with ArgumentError.
    # Plotto.PNG.Rasterizer already uses this same Float.parse/1 pattern for the same
    # reason (see its private num/1 helper).
    test "top positions place the swatch above the plot area (within the reserved band)" do
      margin = Shared.effective_margin(@margin, :top_left, "Sales")
      [swatch, _text] = Shared.legend_elements("Sales", :top_left, "#4E79A7", margin, 600, 400)

      swatch_y = elem(Float.parse(swatch.attrs["y"]), 0)
      assert swatch_y < margin.top
      assert swatch_y > margin.top - Plotto.Theme.legend_row_height()
    end

    test "bottom-position legend does not overlap the x-axis tick labels" do
      margin = Shared.effective_margin(@margin, :bottom_left, "Sales")
      plot_width = 600 - margin.left - margin.right
      plot_height = 400 - margin.top - margin.bottom
      bands = Plotto.Axis.categorical_scale(["Jan", "Feb"], plot_width)

      axis = Shared.axis_elements(bands, margin, plot_width, plot_height, 10)

      max_tick_label_y =
        axis
        |> Enum.filter(&(&1.tag == "text"))
        |> Enum.map(&elem(Float.parse(&1.attrs["y"]), 0))
        |> Enum.max()

      [swatch, _text] = Shared.legend_elements("Sales", :bottom_left, "#4E79A7", margin, 600, 400)
      swatch_y = elem(Float.parse(swatch.attrs["y"]), 0)

      # The legend must sit strictly below (larger y than) every axis tick label —
      # a prior version of this formula placed it on the exact same baseline as the
      # tick labels because it derived the band from the already-enlarged
      # margin.bottom instead of the canvas's absolute bottom edge.
      assert swatch_y > max_tick_label_y
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/shared_test.exs`
Expected: FAIL with `UndefinedFunctionError` for `Shared.effective_margin/3` and `Shared.legend_elements/6`.

- [ ] **Step 3: Implement**

Append to `lib/plotto/svg/renderer/shared.ex`, just before the module's final `end` (after the existing `format_tick/1` clauses):

```elixir
  def effective_margin(margin, legend, name) do
    if draws_legend?(legend, name) do
      case legend do
        position when position in [:top_left, :top_right] ->
          Map.update!(margin, :top, &(&1 + Theme.legend_row_height()))

        position when position in [:bottom_left, :bottom_right] ->
          Map.update!(margin, :bottom, &(&1 + Theme.legend_row_height()))
      end
    else
      margin
    end
  end

  def legend_elements(nil, _legend, _color, _margin, _width, _height), do: []
  def legend_elements(_name, nil, _color, _margin, _width, _height), do: []

  def legend_elements(name, legend, color, margin, width, height) do
    swatch_size = Theme.legend_swatch_size()
    gap = Theme.legend_gap()
    row_height = Theme.legend_row_height()
    font_size = Theme.font_size()

    # Top: the reserved band sits between the base margin.top (where the title lives,
    # at a fixed absolute y independent of margin) and the enlarged margin.top — so it's
    # anchored to `margin.top` (already enlarged by effective_margin/3).
    #
    # Bottom: the x-axis tick labels are positioned *relative to* margin.bottom (see
    # `x_label/2` above), so as margin.bottom grows the tick labels shift down with it —
    # the actual empty space freed up is the last `row_height` pixels of the canvas,
    # anchored to the absolute `height`, NOT to margin.bottom. Anchoring this to
    # margin.bottom instead (as an earlier version of this code did) would place the
    # legend on the exact same baseline as the tick labels for any dataset.
    #
    # Both formulas assume Options.validate/1 has already rejected any :legend value
    # outside Theme.legend_positions/0 — Plotto.Chart.Builder.new/3 guarantees this for
    # charts built via BarChart.new/LineChart.new, but a hand-built chart struct that
    # bypasses that validation would hit a CaseClauseError here.
    y_center =
      case legend do
        position when position in [:top_left, :top_right] -> margin.top - row_height / 2
        position when position in [:bottom_left, :bottom_right] -> height - row_height / 2
      end

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

  defp draws_legend?(legend, name) do
    legend in Theme.legend_positions() and not is_nil(name)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/shared_test.exs`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer/shared.ex test/plotto/svg/renderer/shared_test.exs
git commit -m "Add legend layout (effective_margin/3) and rendering (legend_elements/6) to Renderer.Shared"
```

---

### Task 5: Wire the legend into `Plotto.SVG.Renderer.BarChart`

**Files:**
- Modify: `lib/plotto/svg/renderer/bar_chart.ex:8-28`
- Test: `test/plotto/svg/renderer/bar_chart_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto/svg/renderer/bar_chart_test.exs`:

```elixir
  test "includes a legend swatch and text when :legend and :name are set" do
    chart =
      BarChart.new!([%{label: "Jan", value: 10}], name: "Sales", legend: :top_right)

    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end

  test "does not include a legend when :legend is set but :name is nil" do
    chart = BarChart.new!([%{label: "Jan", value: 10}], legend: :top_right)
    svg = Renderer.render(chart)

    refute Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end

  test "a top legend pushes the y-axis line down by legend_row_height" do
    base_chart = BarChart.new!([%{label: "Jan", value: 10}])
    base_svg = Renderer.render(base_chart)
    [base_y_axis | _] = Enum.filter(base_svg.children, &(&1.tag == "line"))

    legend_chart =
      BarChart.new!([%{label: "Jan", value: 10}], name: "Sales", legend: :top_left)

    legend_svg = Renderer.render(legend_chart)
    [legend_y_axis | _] = Enum.filter(legend_svg.children, &(&1.tag == "line"))

    # Float.parse/1, not String.to_float/1 — margin.top-derived attrs format as plain
    # integer strings (e.g. "40"), which String.to_float/1 rejects. See the note in
    # Task 4's shared_test.exs additions.
    base_y1 = elem(Float.parse(base_y_axis.attrs["y1"]), 0)
    legend_y1 = elem(Float.parse(legend_y_axis.attrs["y1"]), 0)

    assert legend_y1 == base_y1 + Plotto.Theme.legend_row_height()
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/bar_chart_test.exs`
Expected: FAIL — no legend elements are rendered yet, and margin isn't adjusted.

- [ ] **Step 3: Implement**

Replace `lib/plotto/svg/renderer/bar_chart.ex:8-28`:

```elixir
  def render(%Plotto.BarChart{data: data, opts: opts}) do
    margin = Shared.effective_margin(Theme.margin(), opts.legend, opts.name)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = Enum.map(data, & &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = data |> Enum.map(& &1.value) |> Enum.max()

    bars =
      data
      |> Enum.zip(bands)
      |> Enum.with_index()
      |> Enum.map(&build_bar(&1, margin, plot_height, max_value, opts.colors))

    legend =
      Shared.legend_elements(
        opts.name,
        opts.legend,
        Theme.color(opts.colors, 0),
        margin,
        opts.width,
        opts.height
      )

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        bars ++ Shared.title_elements(opts.title, opts.width) ++ legend

    Shared.svg_root(opts.width, opts.height, children)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/bar_chart_test.exs`
Expected: PASS

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `mix test`
Expected: PASS (all existing tests still green — no legend option means unchanged output).

- [ ] **Step 6: Commit**

```bash
git add lib/plotto/svg/renderer/bar_chart.ex test/plotto/svg/renderer/bar_chart_test.exs
git commit -m "Render optional legend in Plotto.SVG.Renderer.BarChart"
```

---

### Task 6: Wire the legend into `Plotto.SVG.Renderer.LineChart`

**Files:**
- Modify: `lib/plotto/svg/renderer/line_chart.ex:8-34`
- Test: `test/plotto/svg/renderer/line_chart_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto/svg/renderer/line_chart_test.exs` (mirrors Task 5's bar chart tests):

```elixir
  test "includes a legend swatch and text when :legend and :name are set" do
    chart =
      LineChart.new!([%{label: "Jan", value: 10}], name: "Revenue", legend: :bottom_left)

    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Revenue"]} -> true
             _ -> false
           end)
  end

  test "does not include a legend when :legend is set but :name is nil" do
    chart = LineChart.new!([%{label: "Jan", value: 10}], legend: :bottom_left)
    svg = Renderer.render(chart)

    refute Enum.any?(svg.children, fn
             %{tag: "text", children: ["Revenue"]} -> true
             _ -> false
           end)
  end

  test "a bottom legend pushes the plot's bottom edge up by legend_row_height" do
    base_chart = LineChart.new!([%{label: "Jan", value: 10}])
    base_svg = Renderer.render(base_chart)
    [_y_axis, base_x_axis | _] = Enum.filter(base_svg.children, &(&1.tag == "line"))

    legend_chart =
      LineChart.new!([%{label: "Jan", value: 10}], name: "Revenue", legend: :bottom_right)

    legend_svg = Renderer.render(legend_chart)
    [_y_axis, legend_x_axis | _] = Enum.filter(legend_svg.children, &(&1.tag == "line"))

    # Float.parse/1, not String.to_float/1 — see the note in Task 4's shared_test.exs
    # additions; these attrs are integer sums and would raise ArgumentError otherwise.
    base_y2 = elem(Float.parse(base_x_axis.attrs["y2"]), 0)
    legend_y2 = elem(Float.parse(legend_x_axis.attrs["y2"]), 0)

    assert legend_y2 == base_y2 - Plotto.Theme.legend_row_height()
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/line_chart_test.exs`
Expected: FAIL

- [ ] **Step 3: Implement**

Replace `lib/plotto/svg/renderer/line_chart.ex:8-34`:

```elixir
  def render(%Plotto.LineChart{data: data, opts: opts}) do
    margin = Shared.effective_margin(Theme.margin(), opts.legend, opts.name)
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = Enum.map(data, & &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = data |> Enum.map(& &1.value) |> Enum.max()
    color = List.first(opts.colors)

    points =
      data
      |> Enum.zip(bands)
      |> Enum.map(fn {item, band} ->
        x = margin.left + band.x
        y = margin.top + Axis.linear_scale(item.value, max_value, plot_height)
        {item, x, y}
      end)

    legend =
      Shared.legend_elements(
        opts.name,
        opts.legend,
        Theme.color(opts.colors, 0),
        margin,
        opts.width,
        opts.height
      )

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        [build_polyline(points, color)] ++
        Enum.map(points, &build_point_circle(&1, color)) ++
        Shared.title_elements(opts.title, opts.width) ++
        legend

    Shared.svg_root(opts.width, opts.height, children)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/line_chart_test.exs`
Expected: PASS

- [ ] **Step 5: Run the full test suite to check for regressions**

Run: `mix test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/plotto/svg/renderer/line_chart.ex test/plotto/svg/renderer/line_chart_test.exs
git commit -m "Render optional legend in Plotto.SVG.Renderer.LineChart"
```

---

### Task 7: End-to-end tests (`Plotto.to_svg!/1`, `Plotto.to_png!/1`)

**Files:**
- Test: `test/plotto_test.exs`

- [ ] **Step 1: Write the failing tests**

Add to `test/plotto_test.exs`:

```elixir
  test "a bar chart with a legend renders the swatch and name end to end in SVG" do
    chart =
      BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}],
        name: "Sales",
        legend: :top_right
      )

    svg = Plotto.to_svg!(chart)
    assert svg =~ "Sales"
  end

  describe "to_png!/1 end-to-end" do
    test "a bar chart with a legend renders without error" do
      chart =
        BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}],
          name: "Sales",
          legend: :bottom_left
        )

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a line chart with a legend renders without error" do
      chart =
        LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}],
          name: "Revenue",
          legend: :top_left
        )

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end
  end
```

Place the first test near the other `to_svg!/1` tests at the top of the file; add the two `describe "to_png!/1 end-to-end"` tests inside the **existing** `describe "to_png!/1 end-to-end"` block (don't create a second block with the same name — merge into it).

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/plotto_test.exs`
Expected: FAIL only if Tasks 1-6 weren't done — since they were, this should mostly serve as a regression/integration check. If any of these fail, something in Tasks 1-6 is wired up incorrectly; stop and fix there before proceeding.

- [ ] **Step 3: Run tests to verify they pass**

Run: `mix test test/plotto_test.exs`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add test/plotto_test.exs
git commit -m "Add end-to-end SVG/PNG tests for chart legends"
```

---

### Task 8: Moduledocs, typespecs, and doctests

**Files:**
- Modify: `lib/plotto/bar_chart.ex`
- Modify: `lib/plotto/line_chart.ex`
- Modify: `lib/plotto.ex`

- [ ] **Step 1: Update `Plotto.BarChart`'s `@type options` and option docs**

In `lib/plotto/bar_chart.ex`, extend the `@type options` map:

```elixir
  @type options :: %{
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          colors: [String.t()],
          name: String.t() | nil,
          legend: :top_left | :top_right | :bottom_left | :bottom_right | nil
        }
```

In the `## Options` doc list (after the `:colors` bullet), add:

```
    * `:name` - optional series name, shown in the legend when `:legend` is also set.
      Defaults to `nil`.
    * `:legend` - optional legend position: `:top_left`, `:top_right`, `:bottom_left`,
      or `:bottom_right`. The legend (a color swatch plus `:name`) only renders when
      **both** `:legend` and `:name` are set — if `:name` is `nil`, nothing is drawn.
      Defaults to `nil` (no legend).
```

In the `## Examples` doctest block, add (after the existing custom-opts example, before the `new([])` error example):

```
      iex> {:ok, chart} =
      ...>   Plotto.BarChart.new(
      ...>     [%{label: "Jan", value: 10}],
      ...>     name: "Sales",
      ...>     legend: :top_right
      ...>   )
      iex> {chart.opts.name, chart.opts.legend}
      {"Sales", :top_right}

      iex> Plotto.BarChart.new([%{label: "Jan", value: 10}], legend: :middle)
      {:error, "invalid legend position, got: :middle"}
```

- [ ] **Step 2: Same updates for `Plotto.LineChart`**

Same `@type options` extension. For the `## Options` doc list, reuse the wording above but note the swatch color source explicitly (since line charts already document that `:colors` only uses the first color):

```
    * `:name` - optional series name, shown in the legend when `:legend` is also set.
      Defaults to `nil`.
    * `:legend` - optional legend position: `:top_left`, `:top_right`, `:bottom_left`,
      or `:bottom_right`. The legend swatch uses the same first color as the line
      itself. Only renders when **both** `:legend` and `:name` are set. Defaults to
      `nil` (no legend).
```

Same two doctest examples, adjusted to `Plotto.LineChart`.

- [ ] **Step 3: Update `Plotto.ex`'s top-level `## Options` section**

In `lib/plotto.ex`, replace:

```elixir
  ## Options

  Both `Plotto.BarChart` and `Plotto.LineChart` accept the same four options via
  `new/2`/`new!/2`: `:width`, `:height`, `:title`, `:colors`. See
  `Plotto.BarChart.new/2` (or `Plotto.LineChart.new/2`) for their exact defaults and
  shapes — line charts differ slightly in how `:colors` is used (only the first color
  is applied, as the single line's stroke), documented there.
```

with:

```elixir
  ## Options

  Both `Plotto.BarChart` and `Plotto.LineChart` accept the same six options via
  `new/2`/`new!/2`: `:width`, `:height`, `:title`, `:colors`, `:name`, `:legend`. See
  `Plotto.BarChart.new/2` (or `Plotto.LineChart.new/2`) for their exact defaults and
  shapes — line charts differ slightly in how `:colors` is used (only the first color
  is applied, as the single line's stroke), documented there. `:name` and `:legend`
  together control an optional single-entry legend (a color swatch plus the series
  name), positioned in one of the chart's four corners.
```

- [ ] **Step 4: Run the doctests**

Run: `mix test test/plotto_test.exs`
Expected: PASS (the file already has `doctest Plotto`, `doctest Plotto.BarChart`, `doctest Plotto.LineChart`, so the new doctest examples run automatically).

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/bar_chart.ex lib/plotto/line_chart.ex lib/plotto.ex
git commit -m "Document :name/:legend options in moduledocs and typespecs"
```

---

### Task 9: README update

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a short mention of the legend feature**

In `README.md`, after the existing paragraph about PNG export (the one starting "If you need to export or generate PNG charts..."), add a new paragraph:

```markdown

Charts can also show an optional title and a single-entry legend (a color swatch plus a series name), positioned in any of the four corners — see `:title`, `:name`, and `:legend` in `Plotto.BarChart` or `Plotto.LineChart`.
```

- [ ] **Step 2: Verify ExDoc still builds cleanly**

Run: `mix docs`
Expected: succeeds with no warnings about broken doc references (README is included via `extras: ["README.md"]` in `mix.exs`).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Mention optional chart legends in README"
```

---

### Task 10: Update examples

**Files:**
- Modify: `examples/bar_chart.exs`
- Modify: `examples/line_chart.exs`
- Regenerate: `examples/bar_chart.svg`, `examples/bar_chart.png`, `examples/line_chart.svg`, `examples/line_chart.png`

- [ ] **Step 1: Check for pre-existing uncommitted changes first**

Run: `git status --porcelain examples/`
`examples/bar_chart.exs` is expected to already show as modified (a pre-existing, unrelated local change adding PNG export lines — see "Before you start" above). Do not discard it.

- [ ] **Step 2: Add `name:`/`legend:` to the example chart**

In `examples/bar_chart.exs`, change:

```elixir
chart = Plotto.BarChart.new!(data, title: "Monthly Sales")
```

to:

```elixir
chart = Plotto.BarChart.new!(data, title: "Monthly Sales", name: "Sales", legend: :top_right)
```

In `examples/line_chart.exs`, change:

```elixir
chart = Plotto.LineChart.new!(data, title: "Monthly Sales")
```

to:

```elixir
chart = Plotto.LineChart.new!(data, title: "Monthly Sales", name: "Sales", legend: :bottom_left)
```

(Deliberately a *bottom* position here, while the bar chart example uses a *top* position — Task 4's bottom-anchoring formula was the one place this plan's own reviewer found and fixed a real overlap bug, so the example set should visually exercise both bands, not just top.)

- [ ] **Step 3: Regenerate the output files**

Run: `mix run examples/bar_chart.exs && mix run examples/line_chart.exs`
Expected: no errors; `examples/bar_chart.svg`, `examples/bar_chart.png`, `examples/line_chart.svg`, `examples/line_chart.png` are all rewritten.

- [ ] **Step 4: Visually spot-check both outputs**

Open `examples/bar_chart.svg` (or its `.png`) and confirm the legend swatch + "Sales" label appear in the top-right corner, above the bars, without overlapping the title.

Open `examples/line_chart.svg` (or its `.png`) and confirm the legend swatch + "Sales" label appear in the bottom-left corner, below the x-axis tick labels ("Jan", "Feb", ...), with visible separation between the two — this is the case Task 4's bug fix specifically targets, so don't skip it.

- [ ] **Step 5: Commit**

Before committing, review `git diff examples/bar_chart.exs` — it will contain both the pre-existing PNG-export lines and this task's `name:`/`legend:` addition. Flag this to the human: ask whether they want the pre-existing PNG-export change committed together with the legend example update, or split out first (e.g. via `git add -p`).

```bash
git add examples/bar_chart.exs examples/bar_chart.svg examples/bar_chart.png \
        examples/line_chart.exs examples/line_chart.svg examples/line_chart.png
git commit -m "Show a legend example in the bar/line chart examples"
```

---

### Task 11: Final full-suite check

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `mix test`
Expected: PASS, all tests green.

- [ ] **Step 2: Run the formatter check**

Run: `mix format --check-formatted`
Expected: no output (already formatted). If it reports unformatted files, run `mix format` and re-check.

- [ ] **Step 3: Commit formatting fixes if any were needed**

```bash
git add -u
git commit -m "Apply mix format"
```

(Skip this step entirely if Step 2 reported nothing to format.)
