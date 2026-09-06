data = [
  %{
    name: "Actual Revenue",
    data: [
      %{label: "Q1", value: 65},
      %{label: "Q2", value: 82},
      %{label: "Q3", value: 95},
      %{label: "Q4", value: 110}
    ]
  },
  %{
    name: "Target Budget",
    data: [
      %{label: "Q1", value: 70},
      %{label: "Q2", value: 85},
      %{label: "Q3", value: 90},
      %{label: "Q4", value: 100}
    ]
  }
]

chart =
  Plotto.BarChart.new!(
    data,
    title: "Quarterly Revenue vs Target ($k)",
    prefix: "$",
    suffix: "k",
    y_max: 120,
    y_max_guide: {:dashed, "#27AE60"},
    y_guidelines: true,
    label: :value,
    legend: :top_center,
    legend_orientation: :horizontal,
    width: 700,
    height: 450
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

svg_path = Path.join(__DIR__, "sales_targets_chart.svg")
png_path = Path.join(__DIR__, "sales_targets_chart.png")

File.write!(svg_path, svg)
File.write!(png_path, png)

IO.puts("Successfully generated:")
IO.puts(" - SVG: #{svg_path}")
IO.puts(" - PNG: #{png_path}")
