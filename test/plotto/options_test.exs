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
end
