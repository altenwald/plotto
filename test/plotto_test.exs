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

  test "bar colors cycle through the palette end to end for 3+ items" do
    colors = Plotto.Theme.default_colors()
    data = for i <- 0..6, do: %{label: "Item#{i}", value: i + 1}
    chart = BarChart.new!(data)
    svg = Plotto.to_svg!(chart)

    fills =
      Regex.scan(~r/<rect fill="(#[0-9A-Fa-f]{6})"/, svg)
      |> Enum.map(fn [_, fill] -> fill end)

    expected = Enum.map(0..6, &Enum.at(colors, rem(&1, length(colors))))

    assert fills == expected
    # 7 items over a 5-color palette: item index 5 wraps back to item index 0's color.
    assert Enum.at(fills, 5) == Enum.at(fills, 0)
  end

  test "custom :colors, :width, and :height thread through new!/2 into the rendered SVG" do
    chart =
      BarChart.new!(
        [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}],
        width: 800,
        height: 500,
        colors: ["#111111", "#222222"]
      )

    svg = Plotto.to_svg!(chart)

    assert svg =~ ~s(width="800")
    assert svg =~ ~s(height="500")
    assert svg =~ ~s(viewBox="0 0 800 500")
    assert svg =~ "#111111"
    assert svg =~ "#222222"
    refute svg =~ "#4E79A7"
  end

  test "to_svg/1 returns {:error, reason} for a value that isn't a supported chart" do
    assert {:error, reason} = Plotto.to_svg(%{not: "a chart"})
    assert is_binary(reason)
  end

  test "to_svg!/1 raises ArgumentError for a value that isn't a supported chart" do
    assert_raise ArgumentError, fn -> Plotto.to_svg!(%{not: "a chart"}) end
  end

  describe "to_png/1 and to_png!/1" do
    @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

    test "to_png/1 returns {:ok, png_binary} for a bar chart, at final (non-supersampled) dimensions" do
      chart =
        BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}],
          width: 100,
          height: 80
        )

      assert {:ok, png} = Plotto.to_png(chart)

      assert binary_part(png, 0, 8) == @png_signature
      <<@png_signature, _length::32, "IHDR", width::32, height::32, _rest::binary>> = png
      assert width == 100
      assert height == 80
    end

    test "to_png!/1 returns the png binary directly for a line chart" do
      chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
      png = Plotto.to_png!(chart)

      assert binary_part(png, 0, 8) == @png_signature
    end

    test "to_png/1 returns {:error, reason} for a value that isn't a supported chart" do
      assert {:error, reason} = Plotto.to_png(%{not: "a chart"})
      assert is_binary(reason)
    end

    test "to_png!/1 raises ArgumentError for a value that isn't a supported chart" do
      assert_raise ArgumentError, fn -> Plotto.to_png!(%{not: "a chart"}) end
    end
  end

  describe "to_png!/1 end-to-end" do
    test "a bar chart with a title, custom colors, and 3+ items renders without error" do
      data = [
        %{label: "Jan", value: 10},
        %{label: "Feb", value: 25},
        %{label: "Mar", value: 18},
        %{label: "Apr", value: 30}
      ]

      chart = BarChart.new!(data, title: "Sales", colors: ["#4E79A7", "#F28E2B"])
      png = Plotto.to_png!(chart)

      assert byte_size(png) > 0
      assert binary_part(png, 0, 8) == @png_signature
    end

    test "a chart with a label containing accented characters renders without error" do
      data = [%{label: "Niño", value: 10}, %{label: "café", value: 15}]
      chart = BarChart.new!(data, title: "Tendencias")

      png = Plotto.to_png!(chart)
      assert binary_part(png, 0, 8) == @png_signature
    end
  end
end
