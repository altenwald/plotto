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

  def linear_scale(value, max_value, plot_height) do
    linear_scale(value, 0, max_value, plot_height)
  end

  def linear_scale(_value, min_value, max_value, plot_height) when min_value == max_value do
    plot_height / 1
  end

  def linear_scale(value, min_value, max_value, plot_height) do
    plot_height - (value - min_value) / (max_value - min_value) * plot_height
  end

  def ticks(max_value) when is_number(max_value) do
    ticks(0, max_value, 5)
  end

  def ticks(min_value, max_value, count \\ 5)

  def ticks(min_value, max_value, _count) when min_value == max_value do
    [min_value]
  end

  def ticks(min_value, max_value, count) do
    step = (max_value - min_value) / count
    for i <- 0..count, do: min_value + i * step
  end
end
