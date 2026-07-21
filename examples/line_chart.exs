data = [
  %{label: "Jan", value: 42},
  %{label: "Feb", value: 58},
  %{label: "Mar", value: 33},
  %{label: "Apr", value: 71},
  %{label: "May", value: 65},
  %{label: "Jun", value: 90}
]

chart = Plotto.LineChart.new!(data, title: "Monthly Sales", name: "Sales", legend: :bottom_left)
svg = Plotto.to_svg!(chart)

File.write!(Path.join(__DIR__, "line_chart.svg"), svg)
