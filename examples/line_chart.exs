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
