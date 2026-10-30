defmodule Plotto.PieChartTest do
  use ExUnit.Case, async: true

  alias Plotto.PieChart

  @slices [
    %{label: "Desktop", value: 60},
    %{label: "Mobile", value: 30},
    %{label: "Tablet", value: 10}
  ]

  @multi_series [
    %{name: "2025", data: [%{label: "Desktop", value: 60}, %{label: "Mobile", value: 40}]},
    %{name: "2026", data: [%{label: "Desktop", value: 45}, %{label: "Mobile", value: 55}]}
  ]

  test "new/2 accepts a flat list of slices and defaults to mode: :pie" do
    assert {:ok, %PieChart{data: [%{name: nil, data: @slices}], opts: opts}} =
             PieChart.new(@slices)

    assert opts.mode == :pie
  end

  test "new/2 accepts a multi-series list and mode: :donut" do
    assert {:ok, %PieChart{data: @multi_series, opts: opts}} =
             PieChart.new(@multi_series, mode: :donut, label: :percent)

    assert opts.mode == :donut
    assert opts.label == :percent
  end

  test "new/2 returns {:error, reason} for invalid data or options" do
    assert {:error, _} = PieChart.new([])
    assert {:error, _} = PieChart.new(@slices, mode: :invalid)
  end

  test "new!/2 returns the struct or raises ArgumentError" do
    assert %PieChart{} = PieChart.new!(@slices)
    assert_raise ArgumentError, fn -> PieChart.new!([]) end
  end

  describe "SVG rendering" do
    test "renders pie slices with colors, tooltips, and custom attrs" do
      data = [
        %{label: "Desktop", value: 60, attrs: %{"phx-click" => "select_desktop"}},
        %{label: "Mobile", value: 40, color: "#FF5733"}
      ]

      chart = PieChart.new!(data, title: "Traffic Share", legend: :right_middle)
      svg = Plotto.to_svg!(chart)

      assert svg =~ "plotto-pie-slice"
      assert svg =~ ~s(phx-click="select_desktop")
      assert svg =~ ~s(fill="#FF5733")
      assert svg =~ "Desktop: 60 (60%)"
      assert svg =~ "Traffic Share"
    end

    test "renders donut mode with inner radius hole" do
      chart = PieChart.new!(@slices, mode: :donut, label: :percent)
      svg = Plotto.to_svg!(chart)

      assert svg =~ "plotto-pie-slice"
      assert svg =~ "plotto-label plotto-label-pie"
      assert svg =~ "60%"
      assert svg =~ "30%"
      assert svg =~ "10%"
    end

    test "supports :value, :label, and callback function for slice labels" do
      val_svg = PieChart.new!(@slices, label: :value, suffix: "k") |> Plotto.to_svg!()
      assert val_svg =~ "60k"
      assert val_svg =~ "30k"

      lbl_svg = PieChart.new!(@slices, label: :label) |> Plotto.to_svg!()
      assert lbl_svg =~ ">Desktop<"
      assert lbl_svg =~ ">Mobile<"

      fn_1_svg =
        PieChart.new!(@slices, label: fn item -> "#{item.label}=#{item.value}" end)
        |> Plotto.to_svg!()

      assert fn_1_svg =~ "Desktop=60"

      fn_2_svg =
        PieChart.new!(@multi_series,
          label: fn item, series_name -> "#{series_name}:#{item.label}" end
        )
        |> Plotto.to_svg!()

      assert fn_2_svg =~ "2025:Desktop"
      assert fn_2_svg =~ "2026:Mobile"
    end

    test "renders a single 100% slice in both pie and donut modes" do
      single_pie = PieChart.new!([%{label: "All", value: 100}], mode: :pie, label: :percent)
      pie_svg = Plotto.to_svg!(single_pie)
      assert pie_svg =~ "plotto-pie-slice"
      assert pie_svg =~ "100%"

      single_donut = PieChart.new!([%{label: "All", value: 100}], mode: :donut, label: :percent)
      donut_svg = Plotto.to_svg!(single_donut)
      assert donut_svg =~ "plotto-pie-slice"
      assert donut_svg =~ "100%"
    end

    test "renders multi-series concentric rings in pie and donut modes" do
      pie_chart = PieChart.new!(@multi_series, mode: :pie, legend: :bottom_center)
      pie_svg = Plotto.to_svg!(pie_chart)
      assert pie_svg =~ "2025 - Desktop: 60 (60%)"
      assert pie_svg =~ "2026 - Mobile: 55 (55%)"

      donut_chart = PieChart.new!(@multi_series, mode: :donut)
      donut_svg = Plotto.to_svg!(donut_chart)
      assert donut_svg =~ "2025 - Desktop: 60 (60%)"
      assert donut_svg =~ "2026 - Mobile: 55 (55%)"
    end

    test "inline: true renders compact 24x24 pie/donut without any text elements" do
      chart =
        PieChart.new!(@slices, inline: true, mode: :donut, label: :percent, title: "Ignored")

      svg = Plotto.to_svg!(chart)

      assert chart.opts.width == 24
      assert chart.opts.height == 24
      assert svg =~ "plotto-chart plotto-inline"
      assert svg =~ "plotto-pie-slice"
      refute svg =~ "<text"
    end
  end
end
