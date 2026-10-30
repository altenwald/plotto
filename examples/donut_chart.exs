data = [
  %{
    name: "2026",
    data: [
      %{label: "Cloud", value: 52},
      %{label: "On-Premise", value: 28},
      %{label: "Hybrid", value: 20}
    ]
  },
  %{
    name: "2025",
    data: [
      %{label: "Cloud", value: 38},
      %{label: "On-Premise", value: 44},
      %{label: "Hybrid", value: 18}
    ]
  }
]

chart =
  Plotto.PieChart.new!(
    data,
    mode: :donut,
    title: "Infrastructure Mix (2025 vs 2026)",
    label: :percent,
    legend: :bottom_center,
    legend_orientation: :horizontal
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "donut_chart.svg"), svg)
File.write!(Path.join(__DIR__, "donut_chart.png"), png)
