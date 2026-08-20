defmodule Plotto.AxisTest do
  use ExUnit.Case, async: true

  alias Plotto.Axis

  describe "categorical_scale/2" do
    test "splits the plot width evenly into one band per label" do
      [a, b, c] = Axis.categorical_scale(["Jan", "Feb", "Mar"], 300)

      assert a == %{label: "Jan", band_x: 0.0, band_width: 100.0, x: 50.0}
      assert b == %{label: "Feb", band_x: 100.0, band_width: 100.0, x: 150.0}
      assert c == %{label: "Mar", band_x: 200.0, band_width: 100.0, x: 250.0}
    end

    test "works with a single label" do
      [only] = Axis.categorical_scale(["Solo"], 200)
      assert only == %{label: "Solo", band_x: 0.0, band_width: 200.0, x: 100.0}
    end
  end

  describe "linear_scale/3" do
    test "maps 0 to the bottom of the plot area" do
      assert Axis.linear_scale(0, 100, 200) == 200.0
    end

    test "maps the max value to the top of the plot area" do
      assert Axis.linear_scale(100, 100, 200) == 0.0
    end

    test "maps an intermediate value proportionally" do
      assert Axis.linear_scale(50, 100, 200) == 100.0
    end

    test "returns the bottom of the plot area when max_value is 0" do
      assert Axis.linear_scale(0, 0, 200) == 200.0
    end
  end

  describe "linear_scale/4" do
    test "maps min_value to the bottom of the plot area" do
      assert Axis.linear_scale(-50, -50, 100, 300) == 300.0
    end

    test "maps max_value to the top of the plot area" do
      assert Axis.linear_scale(100, -50, 100, 300) == 0.0
    end

    test "maps 0 to the proportional baseline between min and max" do
      # Domain [-50, 100] is length 150. 0 is 50 above -50 (1/3 from bottom, so 2/3 from top)
      assert Axis.linear_scale(0, -50, 100, 300) == 200.0
    end

    test "returns bottom of plot area when min_value equals max_value" do
      assert Axis.linear_scale(0, 0, 0, 200) == 200.0
    end
  end

  describe "ticks/3" do
    test "generates nice round integer ticks spanning domain" do
      assert Axis.ticks(0, 74, 5) == [0, 20, 40, 60, 80]
      assert Axis.ticks(0, 100, 5) == [0, 20, 40, 60, 80, 100]
      assert Axis.ticks(-50, 50, 5) == [-60, -40, -20, 0, 20, 40, 60]
    end

    test "generates nice decimal ticks for small ranges" do
      assert Axis.ticks(0.0, 1.0, 5) == [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
    end

    test "returns [min_value] when min_value equals max_value" do
      assert Axis.ticks(-10, -10, 5) == [-10]
    end
  end
end
