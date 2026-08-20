# Design Spec: Candlestick Chart Support

## Status: Draft
## Date: 2026-08-20

## Summary
Add support for Candlestick (OHLC) charts (`Plotto.CandlestickChart`) in Plotto, enabling visualization of financial and price action data (open, high, low, close) in both SVG and PNG formats.

## Goals
- Introduce `Plotto.CandlestickChart` struct with `new/2` and `new!/2` constructors.
- Support OHLC data shape:
  ```elixir
  %{
    label: String.t(),
    open: number(),
    high: number(),
    low: number(),
    close: number(),
    attrs: %{optional(String.t()) => String.t()}
  }
  ```
  Acceptable either as a direct list of OHLC items `[item]` or wrapped in series `[%{name: String.t() | nil, data: [item]}]`.
- Validate OHLC consistency:
  - `high >= max(open, close)`
  - `low <= min(open, close)`
  - All 4 price values are numbers, and `label` is a non-empty string.
- Provide custom styling options in `Plotto.Options`:
  - `:bullish_color` (default: `"#26A69A"`)
  - `:bearish_color` (default: `"#EF5350"`)
  - Standard options: `:width`, `:height`, `:title`, `:legend`.
- Render wick (high to low) as a centered vertical line and candle body (open to close) as a centered rectangle.
- Dynamic Y-axis price domain `[min(lows), max(highs)]` with readable ticks.
- Full SVG output and PNG rasterization without external dependencies.
- Add `examples/candlestick_chart.exs` with `.svg` and `.png` outputs.

## Architecture

### 1. Data Validation (`lib/plotto/candlestick_data.ex` or `lib/plotto/data.ex`)
- Add OHLC validation functions.
- Reject data where `high < max(open, close)` or `low > min(open, close)`.
- Support series wrapping `%{name: name, data: ohlc_items}` or normalize `[ohlc_items]` into single series.

### 2. Options (`lib/plotto/options.ex` & `lib/plotto/theme.ex`)
- `Theme.default_bullish_color/0`: `"#26A69A"`
- `Theme.default_bearish_color/0`: `"#EF5350"`
- `Options.build/1` and `Options.validate/1` supporting `:bullish_color`, `:bearish_color`.

### 3. Chart Struct (`lib/plotto/candlestick_chart.ex`)
- Defines struct `%Plotto.CandlestickChart{data: [series], opts: options}`.
- Provides `new/2` and `new!/2` via `Plotto.Chart.Builder`.

### 4. SVG Renderer (`lib/plotto/svg/renderer/candlestick_chart.ex`)
- Centered wick `<line>`: from `high_y` to `low_y` with stroke color matching candle body.
- Centered body `<rect>`:
  - `top_y = min(open_y, close_y)`
  - `height = max(abs(close_y - open_y), 1.0)` (ensuring doji candles are visible)
  - `width = band.band_width * 0.7`
  - `x = center_x - width / 2`
  - `fill = if close >= open, do: opts.bullish_color, else: opts.bearish_color`
  - Merges item `:attrs`.

### 5. Dispatch & Top-level API (`lib/plotto/svg/renderer.ex` and `lib/plotto.ex`)
- `Plotto.SVG.Renderer.render(%Plotto.CandlestickChart{} = chart)` dispatches to `Plotto.SVG.Renderer.CandlestickChart.render/1`.
- Update `Plotto.to_svg/1` and `Plotto.to_png/1` specs and docs.
