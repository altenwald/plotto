data = [
  %{label: "Jan", value: 42},
  %{label: "Feb", value: 58},
  %{label: "Mar", value: 33},
  %{label: "Apr", value: 71},
  %{label: "May", value: 65},
  %{label: "Jun", value: 90}
]

chart = Plotto.BarChart.new!(data, title: "Monthly Sales")
svg = Plotto.to_svg!(chart)

File.write!(Path.join(__DIR__, "bar_chart.svg"), svg)
