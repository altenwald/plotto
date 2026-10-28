defmodule Plotto.Font.DejaVuSans do
  @moduledoc false

  alias Plotto.Font.TrueType

  @font_path Path.expand("../../../fonts/DejaVuSans.ttf", __DIR__)
  @external_resource @font_path
  # Keep the generated glyph data out of the syntax tree analyzed by Dialyzer.
  @encoded_font @font_path
                |> File.read!()
                |> TrueType.parse!()
                |> :erlang.term_to_binary([:compressed])

  @on_load :load_font

  def load_font do
    :persistent_term.put({__MODULE__, :font}, :erlang.binary_to_term(@encoded_font))
  end

  @spec font() :: TrueType.t()
  def font, do: :persistent_term.get({__MODULE__, :font})
end
