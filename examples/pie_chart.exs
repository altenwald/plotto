data = [
  %{label: "Desktop", value: 48},
  %{label: "Mobile", value: 36},
  %{label: "Tablet", value: 11},
  %{label: "Other", value: 5}
]

chart =
  Plotto.PieChart.new!(
    data,
    title: "Traffic by Device",
    label: :percent,
    legend: :right_middle
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "pie_chart.svg"), svg)
File.write!(Path.join(__DIR__, "pie_chart.png"), png)
