# Design Spec: Support Negative Values

## Status: Draft
## Date: 2026-08-20

## Summary
Add support for negative values in `Plotto.BarChart` (both `:grouped` and `:stacked` modes) and `Plotto.LineChart`. The Y-axis domain expands to `[min_value, max_value]`, where `min_value = min(0, min_data)` and `max_value = max(0, max_data)`. The horizontal axis line is drawn at the zero baseline (`y = linear_scale(0)`), category labels remain anchored below the bottom of the plot area, and bars extend above or below the zero baseline according to sign.

## Goals
- Accept negative numeric values in `Plotto.Data.validate/1`.
- Update `Plotto.Axis.linear_scale/4` and `Plotto.Axis.ticks/3` to map arbitrary `[min_value, max_value]` domains.
- Draw the X-axis baseline at `y = linear_scale(0)` in `Plotto.SVG.Renderer.Shared.axis_elements/6`.
- Render bars in `Plotto.SVG.Renderer.BarChart` extending upwards (for positive values) or downwards (for negative values) from the zero baseline.
- Support stacked bars with mixed signs: positive values stack upwards from 0, negative values stack downwards from 0.
- Render lines and points in `Plotto.SVG.Renderer.LineChart` across negative values.
- Ensure 100% pixel-identical backward compatibility when all data values are non-negative.
- Support full PNG rasterization of charts with negative values.

## Architecture

### 1. Data Validation (`lib/plotto/data.ex`)
Remove the `value < 0` check in `item_error/2`. Only require that `label` is a binary and `value` is a number.

### 2. Domain & Scaling (`lib/plotto/axis.ex`)
- `linear_scale(value, min_value, max_value, plot_height)`:
  - If `min_value == max_value`: returns `plot_height / 1.0`
  - Otherwise: `plot_height - (value - min_value) / (max_value - min_value) * plot_height`
- `ticks(min_value, max_value, count \\ 5)`:
  - If `min_value == max_value`: returns `[min_value]`
  - Otherwise: `step = (max_value - min_value) / count`, returns `[min_value + 0*step, ..., min_value + count*step]`

### 3. Axis Elements (`lib/plotto/svg/renderer/shared.ex`)
- `axis_elements(bands, margin, plot_width, plot_height, min_value, max_value)`:
  - `zero_y = margin.top + Axis.linear_scale(0, min_value, max_value, plot_height)`
  - `x_axis_line` drawn at `y1 = zero_y, y2 = zero_y` from `x1 = margin.left` to `x2 = margin.left + plot_width`.
  - `y_axis_line` drawn from `margin.top` to `margin.top + plot_height`.
  - `x_labels` anchored at `margin.top + plot_height + Theme.font_size() + 4`.
  - `y_labels` placed at each tick from `Axis.ticks(min_value, max_value)`.

### 4. Bar Chart Renderer (`lib/plotto/svg/renderer/bar_chart.ex`)
- **Grouped mode**:
  - `val_y = Axis.linear_scale(item.value, min_value, max_value, plot_height)`
  - `zero_y = Axis.linear_scale(0, min_value, max_value, plot_height)`
  - `top_y = margin.top + min(val_y, zero_y)`
  - `bar_height = abs(val_y - zero_y)`
- **Stacked mode**:
  - Per category, positive values stack upwards from 0 (`pos_base`), negative values stack downwards from 0 (`neg_base`).
  - `min_value = min(0, min_neg_sum)`
  - `max_value = max(0, max_pos_sum)`

### 5. Line Chart Renderer (`lib/plotto/svg/renderer/line_chart.ex`)
- `min_value = min(0, Enum.min(values))`
- `max_value = max(0, Enum.max(values))`
- `y = margin.top + Axis.linear_scale(item.value, min_value, max_value, plot_height)`
