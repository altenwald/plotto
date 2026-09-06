defmodule Plotto.PNG.EncoderTest do
  use ExUnit.Case, async: true

  alias Plotto.PNG.{Canvas, Encoder}

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  test "encode/1 produces a binary starting with the PNG signature" do
    canvas = Canvas.new(2, 2)
    png = Encoder.encode(canvas)

    assert binary_part(png, 0, 8) == @png_signature
  end

  test "encode/1's IHDR chunk reports the canvas dimensions, 8-bit RGBA" do
    canvas = Canvas.new(3, 5)
    png = Encoder.encode(canvas)

    <<@png_signature, _length::32, "IHDR", width::32, height::32, depth::8, color_type::8,
      _rest::binary>> = png

    assert width == 3
    assert height == 5
    assert depth == 8
    assert color_type == 6
  end

  test "encode/1's IDAT chunk decompresses back to the filtered scanline bytes" do
    color = Canvas.pack(10, 20, 30, 255)
    canvas = Canvas.new(1, 1) |> Canvas.put_pixel(0, 0, color)
    png = Encoder.encode(canvas)

    idat_data = extract_chunk(png, "IDAT")
    decompressed = :zlib.uncompress(idat_data)

    # one scanline: filter-type byte (0) + one RGBA pixel
    assert decompressed == <<0, 10, 20, 30, 255>>
  end

  test "encode/1's chunk CRCs are valid" do
    canvas = Canvas.new(2, 2)
    png = Encoder.encode(canvas)

    ihdr_type_and_data = extract_chunk_with_type(png, "IHDR")
    expected_crc = :erlang.crc32(ihdr_type_and_data)

    crc_offset = 8 + 4 + byte_size(ihdr_type_and_data)
    <<_before::binary-size(^crc_offset), actual_crc::32, _rest::binary>> = png

    assert actual_crc == expected_crc
  end

  defp extract_chunk(png, type),
    do:
      extract_chunk_with_type(png, type)
      |> binary_part(4, byte_size(extract_chunk_with_type(png, type)) - 4)

  defp extract_chunk_with_type(png, type) do
    {offset, length} = find_chunk(png, type, 8)
    binary_part(png, offset, length + 4)
  end

  defp find_chunk(png, type, offset) do
    <<_skip::binary-size(^offset), length::32, chunk_type::binary-size(4), _rest::binary>> = png

    if chunk_type == type do
      {offset + 4, length}
    else
      find_chunk(png, type, offset + 4 + 4 + length + 4)
    end
  end
end
