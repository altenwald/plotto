defmodule Plotto.SVG.ElementTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.Element

  test "new/3 defaults to no attrs and no children" do
    element = Element.new("svg")
    assert element.tag == "svg"
    assert element.attrs == %{}
    assert element.children == []
  end

  test "new/3 stringifies attr keys and integer/string values" do
    element = Element.new("rect", %{"fill" => "#FF0000", x: 10})
    assert element.attrs == %{"x" => "10", "fill" => "#FF0000"}
  end

  test "new/3 formats float attr values with 2 decimals" do
    element = Element.new("rect", %{x: 10.5, y: 3.14159})
    assert element.attrs == %{"x" => "10.50", "y" => "3.14"}
  end

  test "new/3 keeps children as given" do
    child = Element.new("text", %{}, ["hello"])
    parent = Element.new("g", %{}, [child])
    assert parent.children == [child]
  end
end
