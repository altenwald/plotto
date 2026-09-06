data = [
  %{
    name: "CPU Utilization",
    color: "#E74C3C",
    data: [
      %{label: "00:00", value: 24},
      %{label: "04:00", value: 18},
      %{label: "08:00", value: 55},
      %{label: "12:00", value: 88},
      %{label: "16:00", value: 76},
      %{label: "20:00", value: 42}
    ]
  },
  %{
    name: "Memory Usage",
    color: "#3498DB",
    dashed: true,
    data: [
      %{label: "00:00", value: 60},
      %{label: "04:00", value: 62},
      %{label: "08:00", value: 68},
      %{label: "12:00", value: 85},
      %{label: "16:00", value: 82},
      %{label: "20:00", value: 70}
    ]
  },
  %{
    name: "Disk I/O",
    color: "#2ECC71",
    dotted: true,
    data: [
      %{label: "00:00", value: 10},
      %{label: "04:00", value: 15},
      %{label: "08:00", value: 35},
      %{label: "12:00", value: 65},
      %{label: "16:00", value: 40},
      %{label: "20:00", value: 20}
    ]
  }
]

chart =
  Plotto.LineChart.new!(
    data,
    title: "Server Performance (24h)",
    suffix: "%",
    y_max: 100,
    y_max_guide: {:dashed, "#C0392B"},
    y_guidelines: true,
    x_guidelines: true,
    legend: :bottom_center,
    legend_orientation: :horizontal,
    stroke_width: 3,
    width: 700,
    height: 450
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

svg_path = Path.join(__DIR__, "server_metrics_chart.svg")
png_path = Path.join(__DIR__, "server_metrics_chart.png")

File.write!(svg_path, svg)
File.write!(png_path, png)

IO.puts("Successfully generated:")
IO.puts(" - SVG: #{svg_path}")
IO.puts(" - PNG: #{png_path}")
