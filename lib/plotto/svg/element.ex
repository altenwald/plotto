defmodule Plotto.SVG.Element do
  @moduledoc false

  defstruct tag: nil, attrs: %{}, children: []

  @type t :: %__MODULE__{
          tag: String.t(),
          attrs: %{optional(String.t()) => String.t()},
          children: [t() | String.t()]
        }

  def new(tag, attrs \\ %{}, children \\ []) do
    %__MODULE__{tag: tag, attrs: stringify_attrs(attrs), children: children}
  end

  defp stringify_attrs(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), format_value(v)} end)
  end

  defp format_value(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp format_value(v), do: to_string(v)
end
