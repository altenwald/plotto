defmodule Plotto.PieData do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    if series_list?(data) do
      validate_series_list(data)
    else
      validate_items(data, nil)
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

  def normalize(data) when is_list(data) do
    if series_list?(data) do
      Enum.map(data, fn series ->
        %{series | data: Enum.map(series.data, &normalize_item/1)}
      end)
    else
      [%{name: nil, data: Enum.map(data, &normalize_item/1)}]
    end
  end

  defp series_list?([first | _]) when is_map(first) do
    Map.has_key?(first, :data) or (Map.has_key?(first, :name) and not Map.has_key?(first, :value))
  end

  defp series_list?(_), do: false

  defp validate_series_list(series_list) do
    with :ok <- validate_each_series(series_list) do
      validate_names(series_list)
    end
  end

  defp validate_each_series(series_list) do
    Enum.find_value(series_list, :ok, fn
      %{name: name, data: []} when is_binary(name) or is_nil(name) ->
        {:error, "series data must not be empty for series: #{inspect(name)}"}

      %{name: "", data: _series_data} ->
        {:error, "series name must not be empty"}

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

  defp validate_items(items, name) do
    with :ok <- validate_each_item(items, name) do
      total = items |> Enum.map(& &1.value) |> Enum.sum()

      if total > 0 do
        :ok
      else
        {:error, "pie chart values must sum to a positive number"}
      end
    end
  end

  defp validate_each_item(items, name) do
    Enum.find_value(items, :ok, fn item ->
      case validate_item(item, name) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp validate_item(%{value: value} = item, name) when is_number(value) do
    label = Map.get(item, :label, Map.get(item, :name))
    color = Map.get(item, :color)
    attrs = Map.get(item, :attrs)

    cond do
      not is_binary(label) or label == "" ->
        invalid_item_error(item, name)

      value < 0 ->
        {:error,
         "pie chart values must be non-negative, got: #{inspect(value)} for #{inspect(label)}"}

      not (is_nil(color) or is_binary(color)) ->
        {:error, "invalid slice :color, expected a color string or nil, got: #{inspect(color)}"}

      not (is_nil(attrs) or is_map(attrs)) ->
        {:error, "invalid slice :attrs, expected a map or nil, got: #{inspect(attrs)}"}

      true ->
        :ok
    end
  end

  defp validate_item(item, name), do: invalid_item_error(item, name)

  defp invalid_item_error(item, nil) do
    {:error,
     "invalid data item, expected a map with :label (string) and non-negative :value (number), " <>
       "got: #{inspect(item)}"}
  end

  defp invalid_item_error(item, name) do
    {:error,
     "invalid data item, expected a map with :label (string) and non-negative :value (number), " <>
       "got: #{inspect(item)} in series: #{inspect(name)}"}
  end

  defp normalize_item(%{} = item) do
    label = Map.get(item, :label, Map.get(item, :name))

    %{label: label, value: item.value}
    |> maybe_copy(item, :color)
    |> maybe_copy(item, :attrs)
  end

  defp maybe_copy(acc, source, key) do
    case Map.fetch(source, key) do
      {:ok, val} when not is_nil(val) -> Map.put(acc, key, val)
      _ -> acc
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
