# TODO

## Support negative values

Right now `Plotto.Data.validate/1` (`lib/plotto/data.ex:14-18`) rejects any
`value < 0`, and the scale/axis code assumes a `[0, max_value]` domain. Just
removing the validation would produce invalid bars (negative `<rect>`
height) and line points that fall off the bottom of the plot area. Approach:

1. **Data validation** (`lib/plotto/data.ex`): drop the `value < 0` check in
   `item_error/1`; keep the type check (label is a string, value is a
   number).

2. **Domain/scale** (`lib/plotto/axis.ex`):
   - Change `linear_scale/3` into `linear_scale(value, min_value, max_value, plot_height)`,
     mapping `[min_value, max_value]` to `[plot_height, 0]`.
   - Change `ticks/2` into `ticks(min_value, max_value, count)`, spanning the
     full domain instead of always starting at 0.
   - Both renderers must compute `min_value = min(0, Enum.min(values))` and
     `max_value = max(0, Enum.max(values))`, so the domain always includes 0
     and today's all-positive charts stay pixel-identical.

3. **Zero baseline** (`lib/plotto/svg/renderer/shared.ex`):
   - `axis_elements/5` currently draws the x-axis line at the bottom of the
     plot area (`margin.top + plot_height`), which is only "zero" because
     the domain always starts at 0 today. It needs to draw at
     `zero_y = linear_scale(0, min_value, max_value, plot_height)` instead.
   - Keep the x-axis tick labels anchored to the bottom of the plot area
     (not the zero line), so they don't collide with bars/points that dip
     below zero.

4. **Bars** (`lib/plotto/svg/renderer/bar_chart.ex`): `build_bar/5` must draw
   from the zero line to the value instead of from the bottom:
   `top_y = min(scale(value), zero_y)`, `height = abs(scale(value) - zero_y)`.
   The current code implicitly assumes `top_y <= plot_height` and
   `height >= 0`, which breaks for negative values.

5. **Lines** (`lib/plotto/svg/renderer/line_chart.ex`): mostly unaffected
   once `Axis.linear_scale/4` takes an explicit domain — points below zero
   just plot below the zero line. Double-check nothing else clips at
   `plot_height`.

6. **PNG path**: no rasterizer change expected
   (`lib/plotto/png/rasterizer.ex` just draws whatever primitives it's
   given), but re-verify once bar `y`/`height` are computed from the zero
   line instead of the bottom.

7. Add regression tests with mixed positive/negative data for both chart
   types (SVG output + PNG smoke test), and update the `examples/*.exs`
   scripts to include a negative value once it renders correctly.
