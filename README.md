# Plotto

Plotto is a plot library, 100% Elixir, that's focused on generating beautiful SVG charts and exporting the same chart to PNG when it's needed — including the PNG rasterizer and TrueType font renderer, no external binaries or NIFs required.

It is very useful when you are developing a website and need to integrate SVG charts. Chart data items accept arbitrary HTML/SVG attributes (`phx-click`, `data-*`, etc.), so if you are using Phoenix LiveView you can attach events, actions, and feedback to individual bars/points — without Plotto depending on Phoenix or LiveView in any way.

If you need to export or generate PNG charts for email, PDF, or sending via Telegram, Slack, Mattermost, etc., `Plotto.to_png/1` renders the same chart to a PNG binary, anti-aliased and with full Unicode text support (including accented characters like á, é, ñ) via a bundled DejaVu Sans font.

Charts can also show an optional title and a legend (one color swatch + name row per series), positioned in any of the four corners — see `:title` and `:legend` in `Plotto.BarChart` or `Plotto.LineChart`. Negative values and mixed positive/negative domains are fully supported with an automatic zero baseline.

## Usage

```elixir
chart =
  Plotto.BarChart.new!(
    [%{name: "Sales", data: [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]}],
    title: "Sales"
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)
```

`Plotto.LineChart` works the same way. See `Plotto.BarChart` and `Plotto.LineChart` for the full data/options shape.

## Examples

[examples/bar_chart.exs](examples/bar_chart.exs) generates the chart below (`mix run examples/bar_chart.exs`), with two series ("Revenue" and "Net Profit"), mixed positive/negative values with a zero baseline, and a top-right legend:

```elixir
data = [
  %{
    name: "Revenue",
    data: [
      %{label: "Jan", value: 42},
      %{label: "Feb", value: 58},
      %{label: "Mar", value: 33},
      %{label: "Apr", value: 71},
      %{label: "May", value: 65},
      %{label: "Jun", value: 90}
    ]
  },
  %{
    name: "Net Profit",
    data: [
      %{label: "Jan", value: 12},
      %{label: "Feb", value: 25},
      %{label: "Mar", value: -15},
      %{label: "Apr", value: 30},
      %{label: "May", value: -8},
      %{label: "Jun", value: 40}
    ]
  }
]

chart = Plotto.BarChart.new!(data, title: "Monthly Performance", legend: :top_right)
svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "bar_chart.svg"), svg)
File.write!(Path.join(__DIR__, "bar_chart.png"), png)
```

![Bar chart example](examples/bar_chart.png)

[examples/stacked_bar_chart.exs](examples/stacked_bar_chart.exs) generates a stacked bar chart (`mix run examples/stacked_bar_chart.exs` with `mode: :stacked`):

```elixir
data = [
  %{
    name: "Hardware",
    data: [
      %{label: "Q1", value: 45},
      %{label: "Q2", value: 50},
      %{label: "Q3", value: 40},
      %{label: "Q4", value: 65}
    ]
  },
  %{
    name: "Software",
    data: [
      %{label: "Q1", value: 30},
      %{label: "Q2", value: 35},
      %{label: "Q3", value: 45},
      %{label: "Q4", value: 55}
    ]
  },
  %{
    name: "Services",
    data: [
      %{label: "Q1", value: 20},
      %{label: "Q2", value: 25},
      %{label: "Q3", value: 30},
      %{label: "Q4", value: 40}
    ]
  }
]

chart =
  Plotto.BarChart.new!(
    data,
    mode: :stacked,
    title: "Quarterly Revenue Breakdown",
    legend: :top_right
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "stacked_bar_chart.svg"), svg)
File.write!(Path.join(__DIR__, "stacked_bar_chart.png"), png)
```

![Stacked bar chart example](examples/stacked_bar_chart.png)

[examples/line_chart.exs](examples/line_chart.exs) generates a line chart with temperatures crossing negative values (`mix run examples/line_chart.exs`), with a bottom-left legend:

```elixir
data = [
  %{
    name: "Temperature",
    data: [
      %{label: "Jan", value: -5},
      %{label: "Feb", value: -2},
      %{label: "Mar", value: 8},
      %{label: "Apr", value: 15},
      %{label: "May", value: 22},
      %{label: "Jun", value: 28}
    ]
  }
]

chart = Plotto.LineChart.new!(data, title: "Monthly Temperatures (°C)", legend: :bottom_left)
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

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/plotto>.

## License

Plotto is licensed under the [MIT License](LICENSE).

Enjoy!
