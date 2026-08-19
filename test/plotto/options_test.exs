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
end
