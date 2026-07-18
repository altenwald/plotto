defmodule Plotto.SVG.SerializerTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.{Element, Serializer}

  test "serializes an element with no children as self-closing" do
    element = Element.new("rect", %{x: 1, y: 2})
    assert Serializer.serialize(element) == ~s(<rect x="1" y="2"/>)
  end

  test "serializes an element with a text child" do
    element = Element.new("text", %{}, ["hello"])
    assert Serializer.serialize(element) == ~s(<text>hello</text>)
  end

  test "serializes nested elements" do
    child = Element.new("rect", %{x: 1})
    parent = Element.new("g", %{}, [child])
    assert Serializer.serialize(parent) == ~s(<g><rect x="1"/></g>)
  end

  test "sorts attributes alphabetically for deterministic output" do
    element = Element.new("rect", %{y: 2, x: 1, fill: "red"})
    assert Serializer.serialize(element) == ~s(<rect fill="red" x="1" y="2"/>)
  end

  test "escapes &, < and > in text content" do
    element = Element.new("text", %{}, ["a < b & c > d"])
    assert Serializer.serialize(element) == ~s(<text>a &lt; b &amp; c &gt; d</text>)
  end

  test "escapes &, <, > and \" in attribute values" do
    element = Element.new("rect", %{"data-label" => ~s(a "b" & <c>)})
    assert Serializer.serialize(element) ==
             ~s(<rect data-label="a &quot;b&quot; &amp; &lt;c&gt;"/>)
  end
end
