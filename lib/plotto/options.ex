defmodule Plotto.Options do
  @moduledoc false

  alias Plotto.Theme

  def build(opts) do
    %{
      width: Keyword.get(opts, :width, Theme.default_width()),
      height: Keyword.get(opts, :height, Theme.default_height()),
      title: Keyword.get(opts, :title),
      colors: Keyword.get(opts, :colors, Theme.default_colors()),
      legend: Keyword.get(opts, :legend)
    }
  end

  def validate(opts) do
    case Keyword.get(opts, :legend) do
      nil ->
        :ok

      position ->
        if position in Theme.legend_positions() do
          :ok
        else
          {:error, "invalid legend position, got: #{inspect(position)}"}
        end
    end
  end
end
