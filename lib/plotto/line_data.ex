defmodule Plotto.LineData do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    if series_list?(data) do
      validate_series_list(data)
    else
      validate_items(data)
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

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

      %{name: name, data: series_data}
      when (is_binary(name) or is_nil(name)) and is_list(series_data) ->
        case validate_items(series_data, name) do
          :ok -> nil
          error -> error
        end

      series ->
        {:error,
         "invalid series, expected a map with :name (string or nil) and :data (list), " <>
           "got: #{inspect(series)}"}
    end)
  end

  defp validate_items(items, name \\ nil) do
    Enum.find_value(items, :ok, fn item ->
      case validate_item(item, name) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp validate_item(%{label: label, value: value}, _name)
       when is_binary(label) and is_number(value),
       do: :ok

  defp validate_item(item, nil) do
    {:error,
     "invalid data item, expected a map with :label (string) and :value (number), " <>
       "got: #{inspect(item)}"}
  end

  defp validate_item(item, name) do
    {:error,
     "invalid data item, expected a map with :label (string) and :value (number), " <>
       "got: #{inspect(item)} in series: #{inspect(name)}"}
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
