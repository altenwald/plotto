data = [
  %{
    name: "Hardware",
    data: [
      %{label: "Q1", value: 45},
      %{label: "Q2", value: 50},
      %{label: "Q3", value: 40},
      %{label: "Q4", value: 65}
    ]
  },
  %{
    name: "Software",
    data: [
      %{label: "Q1", value: 30},
      %{label: "Q2", value: 35},
      %{label: "Q3", value: 45},
      %{label: "Q4", value: 55}
    ]
  },
  %{
    name: "Services",
    data: [
      %{label: "Q1", value: 20},
      %{label: "Q2", value: 25},
      %{label: "Q3", value: 30},
      %{label: "Q4", value: 40}
    ]
  }
]

chart =
  Plotto.BarChart.new!(
    data,
    mode: :stacked,
    title: "Quarterly Revenue Breakdown",
    legend: :top_right
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "stacked_bar_chart.svg"), svg)
File.write!(Path.join(__DIR__, "stacked_bar_chart.png"), png)
