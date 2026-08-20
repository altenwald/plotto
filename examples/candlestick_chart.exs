data = [
  %{label: "09:30", open: 180.5, high: 182.0, low: 179.8, close: 181.6},
  %{label: "10:00", open: 181.6, high: 183.4, low: 181.0, close: 182.9},
  %{label: "10:30", open: 182.9, high: 184.5, low: 182.2, close: 184.1},
  %{label: "11:00", open: 184.1, high: 185.0, low: 183.0, close: 183.2},
  %{label: "11:30", open: 183.2, high: 183.8, low: 181.5, close: 182.0},
  %{label: "12:00", open: 182.0, high: 183.5, low: 181.8, close: 183.0},
  %{label: "12:30", open: 183.0, high: 184.8, low: 182.7, close: 184.5},
  %{label: "13:00", open: 184.5, high: 186.2, low: 184.0, close: 185.8}
]

chart =
  Plotto.CandlestickChart.new!(
    data,
    title: "AAPL Intraday (30m)"
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "candlestick_chart.svg"), svg)
File.write!(Path.join(__DIR__, "candlestick_chart.png"), png)
