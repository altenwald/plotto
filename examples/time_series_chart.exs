# CPU of two hosts over two hours: a numeric time axis (seconds since the Unix epoch, written in UTC), a translucent
# min-max band under each mean line, formatted values and one hover title per instant that lists everything.
start = 1_700_000_000

reading = fn i, base -> Float.round(base + 12 * :math.sin(i / 6) + rem(i * 7, 5), 1) end

series = fn name, color, base ->
  points = for i <- 0..23, do: {start + i * 300, reading.(i, base)}

  [
    %{
      name: "#{name} · Min–Max",
      type: :range,
      color: color,
      data: for({x, v} <- points, do: %{x: x, min: Float.round(v - 6, 1), max: Float.round(v + 9, 1)})
    },
    %{name: "#{name} · Mean", color: color, data: for({x, v} <- points, do: %{x: x, value: v})}
  ]
end

data = series.("web-1", "#4E79A7", 35) ++ series.("web-2", "#F28E2B", 55)

chart =
  Plotto.LineChart.new!(
    data,
    title: "CPU usage",
    x_scale: :time,
    y_min: 0,
    y_max: 100,
    y_format: &"#{round(&1)}%",
    hover: :column,
    points: false,
    legend: :bottom_left,
    legend_orientation: :horizontal,
    y_guidelines: true,
    width: 720
  )

svg = Plotto.to_svg!(chart)
png = Plotto.to_png!(chart)

File.write!(Path.join(__DIR__, "time_series_chart.svg"), svg)
File.write!(Path.join(__DIR__, "time_series_chart.png"), png)
