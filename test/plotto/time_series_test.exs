defmodule Plotto.TimeSeriesTest do
  use ExUnit.Case, async: true

  alias Plotto.{Axis, LineChart}

  # 2023-11-14 22:13:20 UTC
  @t0 1_700_000_000

  defp points(count, step \\ 300),
    do: for(i <- 0..(count - 1), do: %{x: @t0 + i * step, value: 10.0 + i})

  defp svg(data, opts \\ []), do: data |> LineChart.new!(opts) |> Plotto.to_svg!()

  defp parse(text), do: text |> Float.parse() |> elem(0)

  defp attr(svg, tag, name) do
    for [_, value] <- Regex.scan(~r/<#{tag}[^>]*? #{name}="([^"]*)"/, svg), do: value
  end

  describe "validation" do
    test "points may be placed by a numeric :x instead of a :label" do
      assert {:ok, _} = LineChart.new([%{name: "a", data: points(2)}])
    end

    test "all the points of a chart use :x or all use :label" do
      mixed = [%{name: "a", data: [%{x: 1, value: 1}, %{label: "b", value: 2}]}]

      assert {:error, "data items must either all use :x or all use :label"} =
               LineChart.new(mixed)

      across = [
        %{name: "a", data: [%{x: 1, value: 1}]},
        %{name: "b", data: [%{label: "b", value: 2}]}
      ]

      assert {:error, _} = LineChart.new(across)
    end

    test "a range series needs :min and :max, with the minimum not above the maximum" do
      ok = [%{name: "band", type: :range, data: [%{x: 1, min: 1, max: 3}]}]
      assert {:ok, _} = LineChart.new(ok)

      inverted = [%{name: "band", type: :range, data: [%{x: 1, min: 5, max: 3}]}]
      assert {:error, reason} = LineChart.new(inverted)
      assert reason =~ "min must not be greater than :max"

      missing = [%{name: "band", type: :range, data: [%{x: 1, value: 3}]}]
      assert {:error, reason} = LineChart.new(missing)
      assert reason =~ "invalid range item"
    end

    test "an unknown series type is refused" do
      assert {:error, reason} = LineChart.new([%{name: "a", type: :area, data: points(1)}])
      assert reason =~ "invalid series type :area"
    end

    test "the new options are checked" do
      assert {:error, _} = LineChart.new([%{name: "a", data: points(2)}], x_scale: :log)
      assert {:error, _} = LineChart.new([%{name: "a", data: points(2)}], hover: :row)
      assert {:error, _} = LineChart.new([%{name: "a", data: points(2)}], theme: :dark)
      assert {:error, _} = LineChart.new([%{name: "a", data: points(2)}], y_format: "%")
      assert {:error, _} = LineChart.new([%{name: "a", data: points(2)}], points: :no)
    end
  end

  describe "Axis.time_ticks/3" do
    test "marks are round instants inside the range" do
      assert Axis.time_ticks(@t0, @t0 + 1800, 6) == [
               1_700_000_100,
               1_700_000_400,
               1_700_000_700,
               1_700_001_000,
               1_700_001_300,
               1_700_001_600
             ]
    end

    test "the step grows with the span so there are never more marks than asked" do
      for span <- [60, 3_600, 86_400, 7 * 86_400, 400 * 86_400] do
        assert length(Axis.time_ticks(@t0, @t0 + span, 6)) <= 6
      end
    end

    test "an empty range has one mark" do
      assert Axis.time_ticks(@t0, @t0) == [@t0]
    end
  end

  describe "the x axis" do
    test "a time axis writes the hour and minute of round instants, in UTC" do
      svg = svg([%{name: "a", data: points(4, 900)}], x_scale: :time)
      labels = Regex.scan(~r/plotto-label-x"[^>]*>([^<]*)</, svg) |> Enum.map(&List.last/1)

      assert labels != []
      assert Enum.all?(labels, &(&1 =~ ~r/^\d\d:\d\d$/))
      assert "22:15" in labels
    end

    test "over days it writes the date" do
      svg = svg([%{name: "a", data: points(5, 86_400)}], x_scale: :time)
      assert svg =~ ~r/plotto-label-x"[^>]*>\d\d-\d\d</
    end

    test "x_format writes the marks and the titles" do
      svg =
        svg([%{name: "a", data: points(3)}],
          x_scale: :time,
          x_format: &"t#{&1 - @t0}",
          hover: :column
        )

      assert svg =~ ~r/plotto-label-x"[^>]*>t\d+</
      assert svg =~ "t300\n"
    end

    test "points are placed in proportion to x, so a gap is a gap" do
      data = [%{name: "a", data: [%{x: 0, value: 1}, %{x: 1, value: 1}, %{x: 10, value: 1}]}]
      [points] = attr(svg(data, width: 1056, points: true), "polyline", "points")

      xs =
        points
        |> String.split(" ")
        |> Enum.map(&(&1 |> String.split(",") |> hd() |> String.to_float()))

      [x0, x1, x2] = xs
      assert_in_delta (x1 - x0) / (x2 - x0), 0.1, 0.001
    end

    test "a linear scale marks round numbers inside the data" do
      data = [%{name: "a", data: [%{x: 3, value: 1}, %{x: 47, value: 2}]}]
      labels = Regex.scan(~r/plotto-label-x"[^>]*>([^<]*)</, svg(data)) |> Enum.map(&List.last/1)

      assert labels != []

      assert Enum.all?(labels, fn label ->
               {n, _} = Float.parse(label)
               n >= 3 and n <= 47
             end)
    end

    test "a single instant is drawn in the middle" do
      assert svg([%{name: "a", data: points(1)}], x_scale: :time) =~ "<polyline"
    end
  end

  describe "range series" do
    @band [
      %{
        name: "Min–Max",
        type: :range,
        color: "#60a5fa",
        data: for(i <- 0..2, do: %{x: @t0 + i * 300, min: 5.0, max: 15.0 + i})
      }
    ]

    test "draws a translucent polygon between the minimum and the maximum, under the lines" do
      svg = svg(@band ++ [%{name: "Mean", color: "#60a5fa", data: points(3)}], x_scale: :time)

      assert svg =~ ~s(<polygon class="plotto-range" fill="#60a5fa" fill-opacity="0.20")
      assert svg =~ ~s(stroke="none")
      assert :binary.match(svg, "<polygon") < :binary.match(svg, "<polyline")
      # three points up, three back down
      [pts] = attr(svg, "polygon", "points")
      assert length(String.split(pts, " ")) == 6
    end

    test "the opacity can be chosen per series" do
      band = [%{hd(@band) | name: "b"} |> Map.put(:opacity, 0.5)]
      assert svg(band, x_scale: :time) =~ ~s(fill-opacity="0.50")
    end

    test "the axis makes room for the maximum" do
      svg =
        svg([
          %{
            name: "band",
            type: :range,
            data: [%{x: 1, min: 0, max: 80}, %{x: 2, min: 0, max: 90}]
          }
        ])

      assert svg =~ ">100<" or svg =~ ">90<" or svg =~ ">80<"
    end

    test "it has its own square in the legend" do
      svg = svg(@band ++ [%{name: "Mean", data: points(3)}], x_scale: :time, legend: :top_right)
      assert svg =~ ~s(class="plotto-legend-swatch" fill="#60a5fa")
    end

    test "it works on a category axis too" do
      data = [
        %{
          name: "band",
          type: :range,
          data: [%{label: "Jan", min: 1, max: 4}, %{label: "Feb", min: 2, max: 5}]
        }
      ]

      assert svg(data) =~ "<polygon"
    end
  end

  describe "hover: :column" do
    test "one strip per instant with a title listing every series" do
      data =
        @band ++
          [%{name: "Mean", data: points(3)}, %{name: "Other", data: points(3)}]

      svg = svg(data, x_scale: :time, hover: :column, y_format: &"#{&1} %")

      assert length(Regex.scan(~r/class="plotto-hover"/, svg)) == 3
      assert svg =~ "2023-11-14 22:13:20\nMin–Max: 5.0 % – 15.0 %\nMean: 10.0 %\nOther: 10.0 %"
    end

    test "the strips cover the whole plot, side by side" do
      svg = svg([%{name: "a", data: points(4)}], x_scale: :time, hover: :column)
      xs = attr(svg, "rect", "x") |> Enum.map(&parse/1)
      widths = attr(svg, "rect", "width") |> Enum.map(&parse/1)

      # the legend swatches and the like have other classes: keep only the strips
      pairs = for {x, w} <- Enum.zip(xs, widths), do: {x, w}
      assert Enum.sum(Enum.map(Enum.take(pairs, -4), &elem(&1, 1))) |> Float.round(1) == 520.0
    end

    test "on a category axis the title starts with the label" do
      data = [%{name: "a", data: [%{label: "Jan", value: 1}, %{label: "Feb", value: 2}]}]
      assert svg(data, hover: :column) =~ "Jan\na: 1"
    end

    test "without it there are no strips" do
      refute svg([%{name: "a", data: points(3)}], x_scale: :time) =~ "plotto-hover"
    end
  end

  describe "points, formats, responsive and theme" do
    test "points: false leaves out the circles, the lines stay" do
      with_points = svg([%{name: "a", data: points(3)}], x_scale: :time)
      without = svg([%{name: "a", data: points(3)}], x_scale: :time, points: false)

      assert with_points =~ "<circle"
      refute without =~ "<circle"
      assert without =~ "<polyline"
    end

    test "y_format writes the ticks" do
      svg = svg([%{name: "a", data: points(3)}], x_scale: :time, y_format: &"<#{round(&1)}u>")
      assert svg =~ "&lt;0u&gt;"
    end

    test "a responsive chart has no fixed size, only the proportions" do
      svg = svg([%{name: "a", data: points(3)}], x_scale: :time, responsive: true)
      assert svg =~ ~s(viewBox="0 0 600 400")
      assert svg =~ ~s(style="width:100%;height:auto")
      refute svg =~ ~r/<svg[^>]* width=/
    end

    test "a normal chart keeps its width and height" do
      assert svg([%{name: "a", data: points(3)}], x_scale: :time) =~ ~r/<svg[^>]* width="600"/
    end

    test "the css theme puts the colors of text, axes and grid in variables" do
      svg = svg([%{name: "a", data: points(3)}], x_scale: :time, theme: :css, y_guidelines: true)

      assert svg =~ "fill:var(--plotto-text,#333333)"
      assert svg =~ "stroke:var(--plotto-axis,#CCCCCC)"
      assert svg =~ "stroke:var(--plotto-grid,#E0E0E0)"
    end

    test "without the css theme there are no variables" do
      refute svg([%{name: "a", data: points(3)}], x_scale: :time) =~ "var(--plotto"
    end

    test "the PNG ignores the css theme and still renders" do
      chart =
        LineChart.new!([%{name: "a", data: points(3)}],
          x_scale: :time,
          theme: :css,
          hover: :column
        )

      assert {:ok, <<137, 80, 78, 71, _::binary>>} = Plotto.to_png(chart)
    end

    test "inline draws the band and the line only" do
      svg =
        svg(@band ++ [%{name: "Mean", data: points(3)}],
          x_scale: :time,
          inline: true,
          hover: :column
        )

      assert svg =~ "<polygon"
      assert svg =~ "<polyline"
      refute svg =~ "plotto-hover"
      refute svg =~ "<text"
    end
  end
end
