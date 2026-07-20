defmodule Plotto.PNG.Color do
  @moduledoc false

  alias Plotto.PNG.Canvas

  def parse(<<"#", r1, r2, g1, g2, b1, b2>>) do
    with {:ok, r} <- hex_byte(r1, r2),
         {:ok, g} <- hex_byte(g1, g2),
         {:ok, b} <- hex_byte(b1, b2) do
      {:ok, Canvas.pack(r, g, b, 255)}
    end
  end

  def parse(value) do
    {:error, "unsupported color format: #{inspect(value)}, expected \"#RRGGBB\""}
  end

  defp hex_byte(c1, c2) do
    case Integer.parse(<<c1, c2>>, 16) do
      {value, ""} -> {:ok, value}
      _ -> {:error, "invalid hex digits in color"}
    end
  end
end
