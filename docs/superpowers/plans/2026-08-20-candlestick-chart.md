# Implementation Plan: Candlestick Chart Support

## Goal
Implement Candlestick (OHLC) charts (`Plotto.CandlestickChart`), including OHLC data validation, customizable bullish/bearish styling, centered wick and body rendering, SVG/PNG export, and documentation.

## Tasks

- [x] **Task 1: Add Theme defaults and Options for Candlestick charts**
  - Add tests in `test/plotto/theme_test.exs` and `test/plotto/options_test.exs` for `:bullish_color` and `:bearish_color`.
  - Implement default colors in `lib/plotto/theme.ex` and options in `lib/plotto/options.ex`.
  - Verify tests pass and commit.

- [x] **Task 2: Implement OHLC Data validation**
  - Add tests in `test/plotto/candlestick_data_test.exs` (or `data_test.exs`) verifying valid OHLC maps, high >= max(open, close), low <= min(open, close), label string checks, and series/flat normalization.
  - Implement `Plotto.CandlestickData.validate/1` and normalization.
  - Verify tests pass and commit.

- [x] **Task 3: Implement `Plotto.CandlestickChart` module**
  - Add tests in `test/plotto/candlestick_chart_test.exs` for `new/2` and `new!/2`.
  - Implement `Plotto.CandlestickChart` struct, typespecs, and moduledoc.
  - Verify tests pass and commit.

- [x] **Task 4: Implement `Plotto.SVG.Renderer.CandlestickChart`**
  - Add tests in `test/plotto/svg/renderer/candlestick_chart_test.exs` for wick line coordinates, body rect coordinates, bullish/bearish coloring, doji candle minimal height, and item `:attrs`.
  - Implement `Plotto.SVG.Renderer.CandlestickChart.render/1` and wire it up in `Plotto.SVG.Renderer`.
  - Verify tests pass and commit.

- [x] **Task 5: Add end-to-end SVG/PNG tests in `PlottoTest`**
  - Add end-to-end tests for `CandlestickChart` in `test/plotto_test.exs` for `to_svg/1`, `to_svg!/1`, `to_png/1`, `to_png!/1`.
  - Update `lib/plotto.ex` moduledocs and typespecs.
  - Verify tests pass and commit.

- [x] **Task 6: Create example script and update README & TODO**
  - Create `examples/candlestick_chart.exs`.
  - Generate `examples/candlestick_chart.svg` and `examples/candlestick_chart.png`.
  - Update `README.md` and mark Candlestick chart complete in `TODO.md`.
  - Run full suite: `mix test`, `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix docs`.
  - Commit.
