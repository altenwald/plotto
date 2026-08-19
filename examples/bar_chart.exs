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
