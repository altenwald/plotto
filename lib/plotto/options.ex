defmodule Plotto.Options do
  @moduledoc false

  alias Plotto.Theme

  def build(opts) do
    %{
      width: Keyword.get(opts, :width, Theme.default_width()),
      height: Keyword.get(opts, :height, Theme.default_height()),
      title: Keyword.get(opts, :title),
      colors: Keyword.get(opts, :colors, Theme.default_colors())
    }
  end
end
