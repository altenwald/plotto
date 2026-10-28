defmodule Plotto.Font.DejaVuSansTest do
  use ExUnit.Case, async: true

  alias Plotto.Font.{DejaVuSans, TrueType}

  test "font/0 returns the pre-parsed TrueType struct" do
    font = DejaVuSans.font()

    assert font.units_per_em == 2048
    assert map_size(font.glyphs) == 6253
    assert font.cmap[?A] == 36
  end

  test "font/0 preserves every parsed glyph and character mapping" do
    path = Path.expand("../../../fonts/DejaVuSans.ttf", __DIR__)
    expected = TrueType.parse!(File.read!(path))

    assert DejaVuSans.font() == expected
    assert DejaVuSans.font() == expected
  end
end
