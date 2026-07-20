defmodule Plotto.PNG.ColorTest do
  use ExUnit.Case, async: true

  alias Plotto.PNG.{Canvas, Color}

  test "parse/1 converts \"#RRGGBB\" into a fully-opaque packed pixel" do
    assert Color.parse("#FF0000") == {:ok, Canvas.pack(255, 0, 0, 255)}
    assert Color.parse("#00ff00") == {:ok, Canvas.pack(0, 255, 0, 255)}
    assert Color.parse("#4E79A7") == {:ok, Canvas.pack(0x4E, 0x79, 0xA7, 255)}
  end

  test "parse/1 rejects unsupported formats" do
    assert {:error, reason} = Color.parse("#FFF")
    assert reason =~ "#RRGGBB"

    assert {:error, _reason} = Color.parse("red")
    assert {:error, _reason} = Color.parse("rgb(255,0,0)")
  end
end
