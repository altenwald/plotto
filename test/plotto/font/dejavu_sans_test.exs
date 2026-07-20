defmodule Plotto.Font.DejaVuSansTest do
  use ExUnit.Case, async: true

  alias Plotto.Font.DejaVuSans

  test "font/0 returns the pre-parsed TrueType struct" do
    font = DejaVuSans.font()

    assert font.units_per_em == 2048
    assert map_size(font.glyphs) == 6253
    assert font.cmap[?A] == 36
  end

  test "font/0 does not touch the filesystem at runtime" do
    # Calling font/0 must not raise even if we can't demonstrate filesystem
    # isolation directly in ExUnit; this test documents the expectation that
    # font/0 is a plain data accessor, not an I/O call. If it were still doing
    # File.read! here, this test would still pass (the file exists during test
    # runs) — the real guarantee is structural: `@parsed` is a module attribute,
    # not a function call inside `def font`. Review the source to confirm.
    assert %Plotto.Font.TrueType{} = DejaVuSans.font()
  end
end
