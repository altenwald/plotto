defmodule Plotto.GaugeChartTest do
  use ExUnit.Case, async: true

  alias Plotto.GaugeChart

  test "new/2 accepts a single number" do
    assert {:ok, %GaugeChart{data: [%{label: nil, value: 75}]}} = GaugeChart.new(75)
  end

  test "new/2 accepts a single map" do
    assert {:ok, %GaugeChart{data: [%{label: "CPU", value: 75}]}} =
             GaugeChart.new(%{label: "CPU", value: 75})
  end

  test "new/2 accepts multiple items for concentric gauges" do
    items = [
      %{label: "CPU", value: 75},
      %{label: "RAM", value: 60},
      %{label: "Disk", value: 40}
    ]

    assert {:ok, %GaugeChart{data: ^items}} = GaugeChart.new(items)
  end

  test "new/2 applies default options and custom thresholds" do
    {:ok, chart} =
      GaugeChart.new(80,
        title: "Load",
        suffix: "%",
        thresholds: [{60, "#2ECC71"}, {85, "#F1C40F"}, {100, "#E74C3C"}]
      )

    assert chart.opts.title == "Load"
    assert chart.opts.value_suffix == "%"
    assert chart.opts.thresholds == [{60, "#2ECC71"}, {85, "#F1C40F"}, {100, "#E74C3C"}]
  end

  test "new/2 returns {:error, reason} for invalid data or options" do
    assert {:error, _} = GaugeChart.new([])
    assert {:error, _} = GaugeChart.new(75, thresholds: :invalid)
  end

  test "new!/2 returns the struct or raises ArgumentError" do
    assert %GaugeChart{} = GaugeChart.new!(75)
    assert_raise ArgumentError, fn -> GaugeChart.new!([]) end
  end

  describe "SVG rendering" do
    test "single value renders filled arc, transparent track border, minmax, and center value" do
      chart =
        GaugeChart.new!(
          %{label: "CPU Load", value: 78, attrs: %{"phx-click" => "select"}},
          title: "Server Load",
          suffix: "%",
          thresholds: [{60, "#2ECC71"}, {85, "#F1C40F"}, {100, "#E74C3C"}]
        )

      svg = Plotto.to_svg!(chart)

      assert svg =~ "plotto-gauge-arc plotto-gauge-fill"
      assert svg =~ "plotto-gauge-track plotto-axis"
      assert svg =~ ~s(fill="none")
      assert svg =~ ~s(fill="#F1C40F")
      assert svg =~ ~s(phx-click="select")
      assert svg =~ "78%"
      assert svg =~ "CPU Load"
      assert svg =~ "Server Load"
      assert svg =~ "0%"
      assert svg =~ "100%"
    end

    test "single value with thresholds: true selects green/yellow/red based on value" do
      low = GaugeChart.new!(30, thresholds: true) |> Plotto.to_svg!()
      mid = GaugeChart.new!(75, thresholds: true) |> Plotto.to_svg!()
      high = GaugeChart.new!(92, thresholds: true) |> Plotto.to_svg!()

      assert low =~ ~s(fill="#2ECC71")
      assert mid =~ ~s(fill="#F1C40F")
      assert high =~ ~s(fill="#E74C3C")
    end

    test "multiple values render concentric arcs with fixed series colors and stacked center labels" do
      chart =
        GaugeChart.new!(
          [
            %{label: "CPU", value: 80},
            %{label: "Memory", value: 55},
            %{label: "Disk", value: 30}
          ],
          colors: ["#E74C3C", "#3498DB", "#2ECC71"],
          suffix: "%",
          legend: :bottom_center,
          legend_orientation: :horizontal
        )

      svg = Plotto.to_svg!(chart)

      assert svg =~ ~s(fill="#E74C3C")
      assert svg =~ ~s(fill="#3498DB")
      assert svg =~ ~s(fill="#2ECC71")
      assert svg =~ "CPU: 80%"
      assert svg =~ "Memory: 55%"
      assert svg =~ "Disk: 30%"
    end

    test "zero value renders only the transparent track border without a fill path" do
      chart = GaugeChart.new!(%{label: "Idle", value: 0, attrs: %{"data-id" => "zero"}})
      svg = Plotto.to_svg!(chart)

      refute svg =~ "plotto-gauge-fill"
      assert svg =~ "plotto-gauge-track plotto-axis"
      assert svg =~ ~s(data-id="zero")
    end

    test "inline: true renders compact gauge without any text elements" do
      chart = GaugeChart.new!(%{label: "CPU", value: 78}, inline: true, thresholds: true)
      svg = Plotto.to_svg!(chart)

      assert chart.opts.width == 32
      assert chart.opts.height == 24
      assert svg =~ "plotto-chart plotto-inline"
      assert svg =~ "plotto-gauge-fill"
      assert svg =~ "plotto-gauge-track"
      refute svg =~ "<text"
    end
  end
end
