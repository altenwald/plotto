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

  describe "ticks/2" do
    test "generates count + 1 evenly spaced ticks from 0 to max_value" do
      assert Axis.ticks(100, 5) == [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]
    end

    test "defaults to 5 divisions" do
      assert Axis.ticks(10) == [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]
    end

    test "returns [0] when max_value is 0" do
      assert Axis.ticks(0) == [0]
    end
  end
end
