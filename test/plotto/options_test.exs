defmodule Plotto.OptionsTest do
  use ExUnit.Case, async: true

  alias Plotto.Options

  test "fills in defaults when no opts given" do
    opts = Options.build([])
    assert opts.width == Plotto.Theme.default_width()
    assert opts.height == Plotto.Theme.default_height()
    assert opts.title == nil
    assert opts.colors == Plotto.Theme.default_colors()
  end

  test "overrides defaults with given opts" do
    opts = Options.build(width: 800, height: 500, title: "Sales", colors: ["#000000"])
    assert opts.width == 800
    assert opts.height == 500
    assert opts.title == "Sales"
    assert opts.colors == ["#000000"]
  end

  test "fills in :legend as nil by default" do
    opts = Options.build([])
    assert opts.legend == nil
  end

  test "overrides :legend when given" do
    opts = Options.build(legend: :top_right)
    assert opts.legend == :top_right
  end

  test "does not include a :name field" do
    opts = Options.build(name: "Sales")
    refute Map.has_key?(opts, :name)
  end

  test "validate/1 returns :ok when :legend is absent" do
    assert Options.validate([]) == :ok
  end

  test "validate/1 returns :ok for each of the four valid legend positions" do
    for position <- Plotto.Theme.legend_positions() do
      assert Options.validate(legend: position) == :ok
    end
  end

  test "validate/1 returns {:error, reason} for an invalid legend position" do
    assert Options.validate(legend: :middle) ==
             {:error, "invalid legend position, got: :middle"}
  end

  test "fills in :mode as :grouped by default" do
    opts = Options.build([])
    assert opts.mode == :grouped
  end

  test "overrides :mode when given" do
    opts = Options.build(mode: :stacked)
    assert opts.mode == :stacked
  end

  test "validate/1 returns :ok for valid modes" do
    assert Options.validate(mode: :grouped) == :ok
    assert Options.validate(mode: :stacked) == :ok
  end

  test "validate/1 returns {:error, reason} for an invalid mode" do
    assert Options.validate(mode: :invalid) ==
             {:error, "invalid bar chart mode, got: :invalid"}
  end

  test "fills in default bullish_color and bearish_color" do
    opts = Options.build([])
    assert opts.bullish_color == Plotto.Theme.bullish_color()
    assert opts.bearish_color == Plotto.Theme.bearish_color()
  end

  test "overrides bullish_color and bearish_color when given" do
    opts = Options.build(bullish_color: "#00FF00", bearish_color: "#FF0000")
    assert opts.bullish_color == "#00FF00"
    assert opts.bearish_color == "#FF0000"
  end

  test "fills in :label as false by default" do
    opts = Options.build([])
    assert opts.label == false
  end

  test "overrides :label when given" do
    assert Options.build(label: true).label == true
    assert Options.build(label: :value).label == :value
    assert Options.build(labels: true).label == true
  end

  test "validate/1 returns :ok for valid label options" do
    assert Options.validate(label: true) == :ok
    assert Options.validate(label: false) == :ok
    assert Options.validate(label: :label) == :ok
    assert Options.validate(label: :value) == :ok
    assert Options.validate(label: :top) == :ok
    assert Options.validate(label: fn item -> item.label end) == :ok
    assert Options.validate(label: fn item, _series -> item.label end) == :ok
  end

  test "validate/1 returns {:error, reason} for an invalid label option" do
    assert Options.validate(label: :unknown) ==
             {:error,
              "invalid label option, expected true, false, :label, :value, :top, or a 1-2 arity function, got: :unknown"}
  end

  test "validate/1 returns :ok for valid line_styles" do
    assert Options.validate(line_styles: [:solid, :dashed, :dotted, "6,4"]) == :ok
    assert Options.validate(line_style: :dotted) == :ok
  end

  test "validate/1 returns {:error, reason} for invalid line_styles" do
    assert Options.validate(line_styles: [:wavy]) ==
             {:error,
              "invalid line_styles option, expected a list of :solid, :dashed, :dotted, nil, or string dash patterns"}
  end

  test "validate/1 returns :ok for valid stroke_width" do
    assert Options.validate(stroke_width: 2) == :ok
    assert Options.validate(line_width: 1.5) == :ok
  end

  test "validate/1 returns {:error, reason} for invalid stroke_width" do
    assert Options.validate(stroke_width: -1) ==
             {:error, "invalid stroke_width option, expected a positive number, got: -1"}

    assert Options.validate(stroke_width: "thick") ==
             {:error, ~s(invalid stroke_width option, expected a positive number, got: "thick")}
  end

  test "fills in :legend_orientation as :vertical by default" do
    opts = Options.build([])
    assert opts.legend_orientation == :vertical
  end

  test "overrides :legend_orientation when given" do
    opts = Options.build(legend_orientation: :horizontal)
    assert opts.legend_orientation == :horizontal
  end

  test "validate/1 returns :ok for valid legend_orientation" do
    assert Options.validate(legend_orientation: :vertical) == :ok
    assert Options.validate(legend_orientation: :horizontal) == :ok
  end

  test "validate/1 returns {:error, reason} for invalid legend_orientation" do
    assert Options.validate(legend_orientation: :diagonal) ==
             {:error,
              "invalid legend_orientation option, expected :vertical or :horizontal, got: :diagonal"}
  end

  describe "y_max and y_min options" do
    test "fills in y_max and y_min as nil by default, with soft flags" do
      opts = Options.build([])
      assert opts.y_max == nil
      assert opts.y_min == nil
      assert opts.y_max_soft == true
      assert opts.y_min_soft == false
      assert opts.y_max_guide == false
      assert opts.y_min_guide == false
    end

    test "overrides y_bounds and soft options when given" do
      opts =
        Options.build(
          y_max: 100,
          y_min: 0,
          y_max_soft: false,
          y_min_soft: true,
          y_max_guide: {:dashed, "#FF0000"},
          y_min_guide: {:solid, "#0000FF"}
        )

      assert opts.y_max == 100
      assert opts.y_min == 0
      assert opts.y_max_soft == false
      assert opts.y_min_soft == true
      assert opts.y_max_guide == {:dashed, "#FF0000"}
      assert opts.y_min_guide == {:solid, "#0000FF"}
    end

    test "normalizes guide options" do
      assert Options.build(y_max_guide: true).y_max_guide == {:dashed, Plotto.Theme.axis_color()}
      assert Options.build(y_max_guide: "#123456").y_max_guide == {:dashed, "#123456"}
      assert Options.build(y_max_guide: false).y_max_guide == false
      assert Options.build(y_max_guide: nil).y_max_guide == false
    end

    test "validate/1 returns :ok for valid y_min and y_max" do
      assert Options.validate(y_max: 100) == :ok
      assert Options.validate(y_min: 0) == :ok
      assert Options.validate(y_min: -50, y_max: 50) == :ok
      assert Options.validate(y_min: 10.5, y_max: 20.5) == :ok
    end

    test "validate/1 returns {:error, reason} when y_min > y_max" do
      assert Options.validate(y_min: 100, y_max: 50) ==
               {:error, "y_min (100) must be less than or equal to y_max (50)"}
    end

    test "validate/1 returns {:error, reason} for invalid types in y_min or y_max" do
      assert Options.validate(y_min: "zero") ==
               {:error, ~s(invalid y_min option, expected a number, got: "zero")}

      assert Options.validate(y_max: :hundred) ==
               {:error, "invalid y_max option, expected a number, got: :hundred"}
    end

    test "validate/1 returns :ok for valid y_max_soft and y_min_soft" do
      assert Options.validate(y_max_soft: true) == :ok
      assert Options.validate(y_max_soft: false) == :ok
      assert Options.validate(y_min_soft: true) == :ok
      assert Options.validate(y_min_soft: false) == :ok
    end

    test "validate/1 returns {:error, reason} for invalid y_max_soft or y_min_soft" do
      assert Options.validate(y_max_soft: :yes) ==
               {:error, "invalid y_max_soft option, expected a boolean, got: :yes"}

      assert Options.validate(y_min_soft: "no") ==
               {:error, ~s(invalid y_min_soft option, expected a boolean, got: "no")}
    end

    test "validate/1 returns :ok for valid guide options" do
      assert Options.validate(y_max_guide: false) == :ok
      assert Options.validate(y_max_guide: true) == :ok
      assert Options.validate(y_max_guide: "#FF0000") == :ok
      assert Options.validate(y_max_guide: {:solid, "#FF0000"}) == :ok
      assert Options.validate(y_max_guide: {:dashed, "red"}) == :ok
      assert Options.validate(y_max_guide: {:dotted, "#123"}) == :ok
      assert Options.validate(y_min_guide: {:solid, "#000"}) == :ok
    end

    test "validate/1 returns {:error, reason} for invalid guide options" do
      assert Options.validate(y_max_guide: :wavy) ==
               {:error,
                "invalid y_max_guide option, expected false, true, a color string, or {:solid | :dashed | :dotted, color}, got: :wavy"}

      assert Options.validate(y_min_guide: {:zigzag, "#000"}) ==
               {:error,
                "invalid y_min_guide option, expected false, true, a color string, or {:solid | :dashed | :dotted, color}, got: {:zigzag, \"#000\"}"}
    end
  end
end
