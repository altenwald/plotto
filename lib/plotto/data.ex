defmodule Plotto.Data do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    with :ok <- validate_series(data),
         :ok <- validate_matching_labels(data),
         :ok <- validate_names(data) do
      :ok
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

  defp validate_series(series_list) do
    case Enum.find_value(series_list, &series_error/1) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  defp series_error(%{name: name, data: []}) when is_binary(name) or is_nil(name) do
    "series data must not be empty for series: #{inspect(name)}"
  end

  defp series_error(%{name: name, data: series_data})
       when (is_binary(name) or is_nil(name)) and is_list(series_data) do
    Enum.find_value(series_data, &item_error(&1, name))
  end

  defp series_error(series) do
    "invalid series, expected a map with :name (string or nil) and :data (list), " <>
      "got: #{inspect(series)}"
  end

  defp item_error(%{label: label, value: value}, name) when is_binary(label) and is_number(value) do
    if value < 0 do
      "value must not be negative, got: #{inspect(value)} for label #{inspect(label)} " <>
        "in series: #{inspect(name)}"
    else
      nil
    end
  end

  defp item_error(item, name) do
    "invalid data item, expected a map with :label (string) and :value (number), " <>
      "got: #{inspect(item)} in series: #{inspect(name)}"
  end

  defp validate_matching_labels([%{data: first_data} | rest]) do
    expected_labels = Enum.map(first_data, & &1.label)

    case Enum.find_value(rest, &label_mismatch_error(&1, expected_labels)) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  defp label_mismatch_error(%{name: name, data: series_data}, expected_labels) do
    labels = Enum.map(series_data, & &1.label)

    if labels == expected_labels do
      nil
    else
      "series labels must match, expected #{inspect(expected_labels)}, " <>
        "got #{inspect(labels)} for series: #{inspect(name)}"
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
