defmodule Plotto.PNG.Encoder do
  @moduledoc false

  alias Plotto.PNG.Canvas

  @signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  def encode(%Canvas{width: width, height: height} = canvas) do
    ihdr = chunk("IHDR", <<width::32, height::32, 8::8, 6::8, 0::8, 0::8, 0::8>>)
    idat = chunk("IDAT", :zlib.compress(raw_scanlines(canvas)))
    iend = chunk("IEND", <<>>)

    @signature <> ihdr <> idat <> iend
  end

  defp raw_scanlines(canvas) do
    canvas
    |> Canvas.to_scanlines()
    |> Enum.map(fn scanline -> <<0::8, scanline::binary>> end)
    |> IO.iodata_to_binary()
  end

  defp chunk(type, data) do
    length = byte_size(data)
    type_and_data = type <> data
    crc = :erlang.crc32(type_and_data)
    <<length::32, type_and_data::binary, crc::32>>
  end
end
