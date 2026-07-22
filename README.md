# Plotto

Plotto is a plot library, 100% Elixir, that's focused on generating beautiful SVG charts and exporting the same chart to PNG when it's needed — including the PNG rasterizer and TrueType font renderer, no external binaries or NIFs required.

It is very useful when you are developing a website and need to integrate SVG charts. Chart data items accept arbitrary HTML/SVG attributes (`phx-click`, `data-*`, etc.), so if you are using Phoenix LiveView you can attach events, actions, and feedback to individual bars/points — without Plotto depending on Phoenix or LiveView in any way.

If you need to export or generate PNG charts for email, PDF, or sending via Telegram, Slack, Mattermost, etc., `Plotto.to_png/1` renders the same chart to a PNG binary, anti-aliased and with full Unicode text support (including accented characters like á, é, ñ) via a bundled DejaVu Sans font.

Charts can also show an optional title and a single-entry legend (a color swatch plus a series name), positioned in any of the four corners — see `:title`, `:name`, and `:legend` in `Plotto.BarChart` or `Plotto.LineChart`.

## Usage

```elixir
chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}], title: "Sales")
svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)
```

`Plotto.LineChart` works the same way. See `Plotto.BarChart` and `Plotto.LineChart` for the full data/options shape.

## Examples

[examples/bar_chart.exs](examples/bar_chart.exs) generates the chart below (`mix run examples/bar_chart.exs`), including a title and a top-right legend:

```elixir
data = [
  %{label: "Jan", value: 42},
  %{label: "Feb", value: 58},
  %{label: "Mar", value: 33},
  %{label: "Apr", value: 71},
  %{label: "May", value: 65},
  %{label: "Jun", value: 90}
]

chart = Plotto.BarChart.new!(data, title: "Monthly Sales", name: "Sales", legend: :top_right)
svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "bar_chart.svg"), svg)
File.write!(Path.join(__DIR__, "bar_chart.png"), png)
```

![Bar chart example](examples/bar_chart.png)

[examples/line_chart.exs](examples/line_chart.exs) generates the same data as a line chart (`mix run examples/line_chart.exs`), this time with a bottom-left legend:

```elixir
chart = Plotto.LineChart.new!(data, title: "Monthly Sales", name: "Sales", legend: :bottom_left)
svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "line_chart.svg"), svg)
File.write!(Path.join(__DIR__, "line_chart.png"), png)
```

![Line chart example](examples/line_chart.png)

## Installation

The package can be installed by adding `plotto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:plotto, "~> 0.1.0"}
  ]
end
```

Enjoy!
