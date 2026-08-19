# Implementation Plan: Negative Values Support

## Goal
Support negative and mixed values across `Plotto.BarChart` and `Plotto.LineChart`, including axis zero-baseline placement, grouped and stacked bar geometry, and PNG export.

## Tasks

- [x] **Task 1: Allow negative values in `Plotto.Data.validate/1`**
  - Update `test/plotto/data_test.exs` with test asserting negative values pass validation.
  - Remove negative check in `lib/plotto/data.ex`.
  - Verify tests pass and commit.

- [x] **Task 2: Update `Plotto.Axis` linear_scale and ticks for arbitrary domains**
  - Add tests in `test/plotto/axis_test.exs` for `linear_scale/4` and `ticks/2-3` with negative ranges.
  - Implement updated `linear_scale/4` and `ticks/3` in `lib/plotto/axis.ex`.
  - Verify tests pass and commit.

- [x] **Task 3: Update `Plotto.SVG.Renderer.Shared.axis_elements` with zero-baseline**
  - Add tests in `test/plotto/svg/renderer/shared_test.exs` verifying horizontal axis placement at zero baseline and tick label positions.
  - Implement zero baseline in `lib/plotto/svg/renderer/shared.ex`.
  - Verify tests pass and commit.

- [x] **Task 4: Update `Plotto.SVG.Renderer.BarChart` for negative values**
  - Add tests in `test/plotto/svg/renderer/bar_chart_test.exs` for negative bars in grouped mode and stacked mode.
  - Implement negative value handling in `lib/plotto/svg/renderer/bar_chart.ex`.
  - Verify tests pass and commit.

- [x] **Task 5: Update `Plotto.SVG.Renderer.LineChart` for negative values**
  - Add tests in `test/plotto/svg/renderer/line_chart_test.exs` for negative values.
  - Implement domain handling in `lib/plotto/svg/renderer/line_chart.ex`.
  - Verify tests pass and commit.

- [x] **Task 6: Add end-to-end negative value tests and update TODO.md**
  - Add tests in `test/plotto_test.exs` for negative/mixed values in SVG and PNG.
  - Update or remove completed items in `TODO.md`.
  - Run full suite: `mix test`, `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix docs`.
  - Commit.
