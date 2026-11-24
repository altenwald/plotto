defmodule Plotto.LineData do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    with :ok <-
           (if series_list?(data) do
              validate_series_list(data)
            else
              validate_items(data)
            end) do
      validate_single_mode(data)
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

  @doc false
  # Whether the points are placed by a numeric `:x` instead of by a category `:label`.
  def x_mode?(series_list) do
    series_list
    |> Enum.flat_map(& &1.data)
    |> Enum.any?(&Map.has_key?(&1, :x))
  end

  def normalize(data) when is_list(data) do
    if series_list?(data) do
      data
    else
      [%{name: nil, data: data}]
    end
  end

  defp series_list?([first | _]) when is_map(first) do
    Map.has_key?(first, :name) or Map.has_key?(first, :data)
  end

  defp series_list?(_), do: true

  defp validate_series_list(series_list) do
    with :ok <- validate_each_series(series_list) do
      validate_names(series_list)
    end
  end

  defp validate_each_series(series_list) do
    Enum.find_value(series_list, :ok, fn
      %{name: name, data: []} when is_binary(name) or is_nil(name) ->
        {:error, "series data must not be empty for series: #{inspect(name)}"}

      %{name: name, data: series_data} = series
      when (is_binary(name) or is_nil(name)) and is_list(series_data) ->
        case validate_items(series_data, name, Map.get(series, :type, :line)) do
          :ok -> nil
          error -> error
        end

      series ->
        {:error,
         "invalid series, expected a map with :name (string or nil) and :data (list), " <>
           "got: #{inspect(series)}"}
    end)
  end

  defp validate_items(items, name \\ nil, type \\ :line)

  defp validate_items(_items, name, type) when type not in [:line, :range] do
    {:error, "invalid series type #{inspect(type)}, expected :line or :range" <> in_series(name)}
  end

  defp validate_items(items, name, type) do
    Enum.find_value(items, :ok, fn item ->
      case validate_item(item, name, type) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp validate_item(%{label: label, value: value}, _name, :line)
       when is_binary(label) and is_number(value),
       do: :ok

  defp validate_item(%{x: x, value: value}, _name, :line)
       when is_number(x) and is_number(value),
       do: :ok

  defp validate_item(%{min: min, max: max} = item, name, :range)
       when is_number(min) and is_number(max) do
    cond do
      min > max ->
        {:error,
         "invalid range item, :min must not be greater than :max, got: #{inspect(item)}" <>
           in_series(name)}

      is_binary(Map.get(item, :label)) or is_number(Map.get(item, :x)) ->
        :ok

      true ->
        range_error(item, name)
    end
  end

  defp validate_item(item, name, :range), do: range_error(item, name)

  defp validate_item(item, name, :line) do
    {:error,
     "invalid data item, expected a map with :label (string) or :x (number) and :value (number), " <>
       "got: #{inspect(item)}" <> in_series(name)}
  end

  defp range_error(item, name) do
    {:error,
     "invalid range item, expected a map with :label (string) or :x (number) and :min and :max (numbers), " <>
       "got: #{inspect(item)}" <> in_series(name)}
  end

  defp in_series(nil), do: ""
  defp in_series(name), do: " in series: #{inspect(name)}"

  # Points are placed either by category (`:label`) or by a numeric position (`:x`), never both in one chart.
  defp validate_single_mode(data) do
    items = data |> normalize() |> Enum.flat_map(& &1.data)

    if Enum.any?(items, &Map.has_key?(&1, :x)) and Enum.any?(items, &(not Map.has_key?(&1, :x))) do
      {:error, "data items must either all use :x or all use :label"}
    else
      :ok
    end
  end

  defp validate_names([_single_series]), do: :ok

  defp validate_names(series_list) do
    case Enum.find_value(series_list, &nil_name_error/1) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  defp nil_name_error(%{name: nil}), do: "series name is required when there are multiple series"
  defp nil_name_error(_series), do: nil
end
