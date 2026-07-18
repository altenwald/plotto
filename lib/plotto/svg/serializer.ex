defmodule Plotto.SVG.Serializer do
  @moduledoc false

  alias Plotto.SVG.Element

  def serialize(%Element{} = element) do
    render_element(element)
  end

  defp render_element(%Element{tag: tag, attrs: attrs, children: children}) do
    attrs_string = render_attrs(attrs)

    if children == [] do
      "<#{tag}#{attrs_string}/>"
    else
      children_string = Enum.map_join(children, "", &render_child/1)
      "<#{tag}#{attrs_string}>#{children_string}</#{tag}>"
    end
  end

  defp render_child(%Element{} = child), do: render_element(child)
  defp render_child(text) when is_binary(text), do: escape_text(text)

  defp render_attrs(attrs) do
    attrs
    |> Enum.sort()
    |> Enum.map_join("", fn {k, v} -> ~s( #{k}="#{escape_attr(v)}") end)
  end

  defp escape_attr(value) do
    value
    |> escape_text()
    |> String.replace("\"", "&quot;")
  end

  defp escape_text(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
