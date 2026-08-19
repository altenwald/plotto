# TODO

## Candlestick charts (Gráficos de Velas)

Add support for candlestick (OHLC) charts (`Plotto.CandlestickChart`), commonly used for financial and trading data.

### 1. Data Shape & Validation
- Data points represent OHLC intervals:
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
- Validation rules:
  - `high >= max(open, close)`
  - `low <= min(open, close)`
  - `label` is a string, and all 4 price values are numeric.

### 2. Geometry & Rendering
- **Wick (Shadow)**: Vertical line centered in the category band from `high` down to `low`.
- **Body (Candle)**: Rectangle centered in the category band from `min(open, close)` to `max(open, close)`.
- **Colors**:
  - Bullish / Up candle (`close >= open`): green / positive fill color (e.g. `Theme.bullish_color()` or configurable `:bullish_color`).
  - Bearish / Down candle (`close < open`): red / negative fill color (e.g. `Theme.bearish_color()` or configurable `:bearish_color`).
- **Scale & Axes**:
  - Y-axis domain spans `[min(lows), max(highs)]`.
  - X-axis categorical scale with date/time labels.

### 3. Options & Export
- Configurable options: `:width`, `:height`, `:title`, `:bullish_color`, `:bearish_color`, `:wick_color`.
- Full SVG output and PNG rasterization support.
- Example script `examples/candlestick_chart.exs` with `.svg` and `.png` generation.
