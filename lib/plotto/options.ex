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
      mode: Keyword.get(opts, :mode, :grouped),
      bullish_color: Keyword.get(opts, :bullish_color, Theme.bullish_color()),
      bearish_color: Keyword.get(opts, :bearish_color, Theme.bearish_color()),
      tooltip: Keyword.get(opts, :tooltip, :data)
    }
  end

  def validate(opts) do
    with :ok <- validate_legend(Keyword.get(opts, :legend)),
         :ok <- validate_mode(Keyword.get(opts, :mode)),
         :ok <- validate_tooltip(Keyword.get(opts, :tooltip)) do
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

  defp validate_tooltip(nil), do: :ok
  defp validate_tooltip(false), do: :ok
  defp validate_tooltip(mode) when mode in [:data, :native, :title], do: :ok
  defp validate_tooltip(fun) when is_function(fun, 1) or is_function(fun, 2), do: :ok

  defp validate_tooltip(invalid) do
    {:error,
     "invalid tooltip option, expected :data, :native, :title, false, or a 1-2 arity function, got: #{inspect(invalid)}"}
  end
end
