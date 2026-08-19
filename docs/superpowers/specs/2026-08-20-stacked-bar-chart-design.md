# Design Spec: Stacked Bar Chart Support

## Status: Draft
## Date: 2026-08-20

## Summary
Add support for stacked bar charts to `Plotto.BarChart` via a new `:mode` option (`:grouped` | `:stacked`, defaulting to `:grouped`). In stacked mode, multi-series values within each category are stacked vertically on top of each other into a single full-width bar, with the Y-axis scaled to the maximum category sum across all series.

## Goals
- Add `:mode` option (`:grouped` | `:stacked`) to `Plotto.Options` and `Plotto.BarChart`.
- Default `:mode` to `:grouped`, keeping 100% backward compatibility with existing single-series and multi-series grouped bar charts.
- In `:stacked` mode:
  - Calculate `max_value` across categories as the maximum sum of values per category: $\max_c \sum_{s} v_{s,c}$.
  - Bar segments occupy the full inner category width (`band.band_width * 0.8`).
  - Each series $s$ segment is drawn from cumulative bottom $\sum_{i=0}^{s-1} v_{i,c}$ to top $\sum_{i=0}^{s} v_{i,c}$.
  - Segment fill colors cycle per series (`Theme.color(colors, series_index)`).
  - Per-item `:attrs` are preserved on each segment `<rect>`.
- Multi-entry legend continues to display each series name and color swatch.
- Provide full SVG and PNG export support without changes to the PNG rasterizer.
- Add an example script [`examples/stacked_bar_chart.exs`](file:///Users/manuel/Projects/Altenwald/plotto/examples/stacked_bar_chart.exs) with generated `.svg` and `.png` artifacts.

## Non-Goals
- 100% normalized stacked bars (percentage basis) — in this phase, bars represent absolute numeric sums.
- Stacked area charts or stacked line charts (reserved for future phases).

## Architecture & Implementation

### 1. `Plotto.Options`
- `build/1`:
  - `mode: Keyword.get(opts, :mode, :grouped)`
- `validate/1`:
  - Validates `mode in [:grouped, :stacked, nil]`.
  - Returns `{:error, "invalid bar chart mode, got: ..."` on invalid values.

### 2. `Plotto.BarChart`
- Update `@type options` to include `mode: :grouped | :stacked`.
- Update `@type t` and docstrings.

### 3. `Plotto.SVG.Renderer.BarChart`
- When `opts.mode == :stacked`:
  - Compute category totals across series:
    ```elixir
    category_totals =
      data
      |> Enum.map(fn series -> Enum.map(series.data, & &1.value) end)
      |> List.zip()
      |> Enum.map(fn tuple -> Tuple.to_list(tuple) |> Enum.sum() end)

    max_value = if category_totals == [], do: 0, else: Enum.max(category_totals)
    ```
  - For each category index $c$ and band:
    - Compute cumulative bottom and top values for each series $s$.
    - `bar_x = margin.left + band.band_x + band.band_width * 0.1`
    - `bar_width = band.band_width * 0.8`
    - `top_y = margin.top + Axis.linear_scale(top_val, max_value, plot_height)`
    - `bottom_y = margin.top + Axis.linear_scale(bottom_val, max_value, plot_height)`
    - `bar_height = bottom_y - top_y`
    - Segment attributes merged with item `:attrs`.

## Testing Strategy
- `Plotto.OptionsTest`: Validate `:mode` option parsing and validation (`:grouped`, `:stacked`, invalid).
- `Plotto.BarChartTest`: Validate `:mode` option in `new/2` and `new!/2`.
- `Plotto.SVG.Renderer.BarChartTest`:
  - Render stacked bars: 1 <rect> per series per category with full `inner_width`.
  - Check vertical stacking: segment top_y equals next segment's bottom_y.
  - Check Y-axis `max_value` scales to the category sum.
- `PlottoTest`: End-to-end SVG and PNG smoke tests for stacked bar charts.
- `examples/stacked_bar_chart.exs`: Script producing `stacked_bar_chart.svg` and `stacked_bar_chart.png`.
