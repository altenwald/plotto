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

  describe "calculate_y_domain/3" do
    test "defaults to baseline 0 for non-negative data" do
      assert Axis.calculate_y_domain(10, 50, %{}) == {0, 50}
    end

    test "defaults to data_min when data contains negative values" do
      assert Axis.calculate_y_domain(-20, 50, %{}) == {-20, 50}
    end

    test "y_max with y_max_soft: true expands to y_max when data_max < y_max" do
      opts = %{y_max: 100, y_max_soft: true}
      assert Axis.calculate_y_domain(10, 63, opts) == {0, 100}
    end

    test "y_max with y_max_soft: true expands to data_max when data_max > y_max" do
      opts = %{y_max: 100, y_max_soft: true}
      assert Axis.calculate_y_domain(10, 125, opts) == {0, 125}
    end

    test "y_max with y_max_soft: false strictly sets upper bound" do
      opts = %{y_max: 100, y_max_soft: false}
      assert Axis.calculate_y_domain(10, 125, opts) == {0, 100}
    end

    test "y_min with y_min_soft: false strictly sets lower bound" do
      opts = %{y_min: 20, y_min_soft: false}
      assert Axis.calculate_y_domain(30, 80, opts) == {20, 80}
    end

    test "y_min with y_min_soft: true expands to data_min when data_min < y_min" do
      opts = %{y_min: 20, y_min_soft: true}
      assert Axis.calculate_y_domain(5, 80, opts) == {5, 80}
    end
  end
end
