data = [
  %{label: "CPU", value: 78},
  %{label: "Memory", value: 62},
  %{label: "Disk", value: 45}
]

chart =
  Plotto.GaugeChart.new!(
    data,
    title: "System Resources",
    suffix: "%",
    legend: :bottom_center,
    legend_orientation: :horizontal
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "multi_gauge_chart.svg"), svg)
File.write!(Path.join(__DIR__, "multi_gauge_chart.png"), png)
