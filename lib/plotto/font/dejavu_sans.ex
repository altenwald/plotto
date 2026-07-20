defmodule Plotto.Font.DejaVuSans do
  @moduledoc false

  @font_path Path.expand("../../../fonts/DejaVuSans.ttf", __DIR__)
  @external_resource @font_path
  @parsed Plotto.Font.TrueType.parse!(File.read!(@font_path))

  def font, do: @parsed
end
