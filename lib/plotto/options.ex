defmodule Plotto.Options do
  @moduledoc false

  alias Plotto.Theme

  @modes [:grouped, :stacked]

  def modes, do: @modes

  def build(opts) do
    %{
      width: Keyword.get(opts, :width, Theme.default_width()),
      height: Keyword.get(opts, :height, Theme.default_height()),
      title: Keyword.get(opts, :title),
      colors: Keyword.get(opts, :colors, Theme.default_colors()),
      legend: Keyword.get(opts, :legend),
      mode: Keyword.get(opts, :mode, :grouped)
    }
  end

  def validate(opts) do
    with :ok <- validate_legend(Keyword.get(opts, :legend)),
         :ok <- validate_mode(Keyword.get(opts, :mode)) do
      :ok
    end
  end

  defp validate_legend(nil), do: :ok

  defp validate_legend(position) do
    if position in Theme.legend_positions() do
      :ok
    else
      {:error, "invalid legend position, got: #{inspect(position)}"}
    end
  end

  defp validate_mode(nil), do: :ok

  defp validate_mode(mode) do
    if mode in @modes do
      :ok
    else
      {:error, "invalid bar chart mode, got: #{inspect(mode)}"}
    end
  end
end
