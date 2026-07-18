# Plotto

Plotto is a plot library, 100% Elixir, that's focused on generating beautiful SVG charts and (in a future release) exporting the same chart to PNG when it's needed.

It is very useful when you are developing a website and need to integrate SVG charts. Chart data items accept arbitrary HTML/SVG attributes (`phx-click`, `data-*`, etc.), so if you are using Phoenix LiveView you can attach events, actions, and feedback to individual bars/points — without Plotto depending on Phoenix or LiveView in any way.

PNG export (for email, PDF, or sending via Telegram, Slack, Mattermost, etc.) is on the roadmap but not yet implemented; the current release generates SVG only.

## Usage

```elixir
chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}], title: "Sales")
svg = Plotto.to_svg!(chart)
```

`Plotto.LineChart` works the same way. See `Plotto.BarChart` and `Plotto.LineChart` for the full data/options shape.

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
