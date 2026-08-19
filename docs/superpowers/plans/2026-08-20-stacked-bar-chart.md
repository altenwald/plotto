# Implementation Plan: Stacked Bar Chart Support

## Goal
Implement stacked bar charts in `Plotto.BarChart` via the `:mode` option (`:grouped` | `:stacked`), with full SVG and PNG export support, unit/integration tests, and an example script.

## Tasks

- [x] **Task 1: Add `:mode` option to `Plotto.Options`**
  - Add failing tests to `test/plotto/options_test.exs` for `:mode` default (`:grouped`), override (`:stacked`), and validation.
  - Implement `:mode` in `lib/plotto/options.ex`.
  - Verify tests pass and commit.

- [x] **Task 2: Update `Plotto.BarChart` typespecs, docs, and validation tests**
  - Add tests for `:mode` in `test/plotto/bar_chart_test.exs`.
  - Update `lib/plotto/bar_chart.ex` `@type options` and docstrings.
  - Verify tests pass and commit.

- [x] **Task 3: Implement stacked bar rendering in `Plotto.SVG.Renderer.BarChart`**
  - Add failing unit tests in `test/plotto/svg/renderer/bar_chart_test.exs` for `:stacked` mode (cumulative height, full bar width, category sum max_value, attrs merging).
  - Implement stacked mode rendering in `lib/plotto/svg/renderer/bar_chart.ex`.
  - Verify tests pass and commit.

- [x] **Task 4: Add end-to-end tests for stacked bar charts**
  - Add tests in `test/plotto_test.exs` for SVG and PNG rendering of stacked bar charts.
  - Verify all tests pass and commit.

- [x] **Task 5: Create example script and generate visual artifacts**
  - Create `examples/stacked_bar_chart.exs`.
  - Run `mix run examples/stacked_bar_chart.exs` to generate `stacked_bar_chart.svg` and `stacked_bar_chart.png`.
  - Verify visual artifacts and commit.

- [x] **Task 6: Verification and documentation**
  - Run `mix test`, `mix format --check-formatted`, `mix compile --warnings-as-errors`, and `mix docs`.
  - Update plan checkboxes and commit.
