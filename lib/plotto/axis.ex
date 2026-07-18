defmodule Plotto.Axis do
  @moduledoc false

  def categorical_scale(labels, plot_width) do
    band_width = plot_width / length(labels)

    labels
    |> Enum.with_index()
    |> Enum.map(fn {label, index} ->
      band_x = index * band_width
      %{label: label, band_x: band_x, band_width: band_width, x: band_x + band_width / 2}
    end)
  end

  def linear_scale(_value, 0, plot_height), do: plot_height / 1

  def linear_scale(value, max_value, plot_height) do
    plot_height - value / max_value * plot_height
  end

  def ticks(max_value, count \\ 5)
  def ticks(0, _count), do: [0]

  def ticks(max_value, count) do
    step = max_value / count
    for i <- 0..count, do: i * step
  end
end
