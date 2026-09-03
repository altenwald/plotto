data = [
  %{
    name: "Elektrogriff (Gewitterbote)",
    dashed: true,
    color: "#9B59B6",
    data: [
      %{label: "1", value: 12},
      %{label: "2", value: 49},
      %{label: "3", value: 74},
      %{label: "4", value: 87},
      %{label: "5", value: 98}
    ]
  },
  %{
    name: "Sturmbogen (Wüstenjägerin)",
    color: "#8E44AD",
    data: [
      %{label: "1", value: 0},
      %{label: "2", value: 12},
      %{label: "3", value: 26},
      %{label: "4", value: 49},
      %{label: "5", value: 63},
      %{label: "6", value: 75},
      %{label: "7", value: 80},
      %{label: "8", value: 96}
    ]
  },
  %{
    name: "Jagddolch (Wüstenjägerin)",
    color: "#4A235A",
    data: [
      %{label: "1", value: 0},
      %{label: "2", value: 1},
      %{label: "3", value: 5},
      %{label: "4", value: 12},
      %{label: "5", value: 25},
      %{label: "6", value: 27},
      %{label: "7", value: 40},
      %{label: "8", value: 50},
      %{label: "9", value: 52},
      %{label: "10", value: 63}
    ]
  }
]

chart =
  Plotto.LineChart.new!(
    data,
    legend: :right_top,
    stroke_width: 3,
    width: 700,
    height: 450
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

svg_path = Path.join(__DIR__, "weapons_chart.svg")
png_path = Path.join(__DIR__, "weapons_chart.png")

File.write!(svg_path, svg)
File.write!(png_path, png)

IO.puts("Successfully generated:")
IO.puts(" - SVG: #{svg_path}")
IO.puts(" - PNG: #{png_path}")
