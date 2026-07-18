defmodule PlottoTest do
  use ExUnit.Case, async: true

  doctest Plotto.BarChart
  doctest Plotto.LineChart

  alias Plotto.{BarChart, LineChart}

  test "to_svg/1 returns {:ok, svg_string} for a bar chart" do
    chart = BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    assert {:ok, svg} = Plotto.to_svg(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<rect"
  end

  test "to_svg!/1 returns the svg string directly for a line chart" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Plotto.to_svg!(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<polyline"
  end

  test "per-item attrs pass through end to end into the SVG output" do
    chart =
      BarChart.new!([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}])

    svg = Plotto.to_svg!(chart)
    assert svg =~ ~s(phx-click="select")
  end

  test "labels with special characters are escaped end to end" do
    chart = BarChart.new!([%{label: "<script>", value: 10}])
    svg = Plotto.to_svg!(chart)
    refute svg =~ "<script>"
    assert svg =~ "&lt;script&gt;"
  end
end
