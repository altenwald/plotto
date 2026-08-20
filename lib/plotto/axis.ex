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

  def ticks(min_value, max_value, max_ticks \\ 5)

  def ticks(min_value, max_value, _max_ticks) when min_value == max_value do
    [min_value]
  end

  def ticks(min_value, max_value, max_ticks) when min_value < max_value do
    range = max_value - min_value
    step = calculate_nice_step(range, max_ticks)
    nice_min = Float.floor(min_value / step) * step
    nice_max = Float.ceil(max_value / step) * step

    is_integer_step = step == trunc(step) and nice_min == trunc(nice_min)
    n_intervals = round((nice_max - nice_min) / step)

    if is_integer_step do
      start = trunc(nice_min)
      s = trunc(step)
      for i <- 0..n_intervals, do: start + i * s
    else
      for i <- 0..n_intervals, do: Float.round(nice_min + i * step, 6)
    end
  end

  def ticks(min_value, max_value, max_ticks) when min_value > max_value do
    ticks(max_value, min_value, max_ticks)
  end

  defp calculate_nice_step(range, max_ticks) do
    target_ticks = max(1, max_ticks)
    raw_step = range / target_ticks
    e = :math.floor(:math.log10(raw_step))
    magnitude = :math.pow(10, e)
    fraction = raw_step / magnitude

    multipliers = [1.0, 2.0, 2.5, 5.0, 10.0, 20.0, 25.0, 50.0, 100.0]

    Enum.find_value(multipliers, 10.0 * magnitude, fn m ->
      s = m * magnitude
      intervals = round(Float.ceil(range / s) * s / s)
      if intervals <= target_ticks and m >= fraction, do: s
    end) || 10.0 * magnitude
  end
end
