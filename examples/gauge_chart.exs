chart =
  Plotto.GaugeChart.new!(
    %{label: "CPU Load", value: 78},
    title: "Server CPU Utilization",
    suffix: "%",
    thresholds: [
      {60, "#2ECC71"},
      {85, "#F1C40F"},
      {100, "#E74C3C"}
    ]
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "gauge_chart.svg"), svg)
File.write!(Path.join(__DIR__, "gauge_chart.png"), png)
