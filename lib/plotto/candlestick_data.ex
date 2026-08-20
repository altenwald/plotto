defmodule Plotto.CandlestickData do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    case data do
      [%{data: series_data} | _] when is_list(series_data) ->
        validate_series_list(data)

      _ ->
        validate_items(data)
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

  def normalize([%{data: series_data} | _] = data) when is_list(series_data) do
    data
  end

  def normalize(data) when is_list(data) do
    [%{name: nil, data: data}]
  end

  defp validate_series_list(series_list) do
    Enum.find_value(series_list, :ok, fn
      %{data: items} when is_list(items) and items != [] ->
        case validate_items(items) do
          :ok -> nil
          error -> error
        end

      %{data: []} ->
        {:error, "series data must not be empty"}

      series ->
        {:error, "invalid series: #{inspect(series)}"}
    end)
  end

  defp validate_items(items) do
    Enum.find_value(items, :ok, fn item ->
      case validate_item(item) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp validate_item(%{label: label, open: open, high: high, low: low, close: close})
       when is_binary(label) and is_number(open) and is_number(high) and is_number(low) and
              is_number(close) do
    max_price = max(open, close)
    min_price = min(open, close)

    cond do
      high < max_price ->
        {:error, "high price (#{high}) must be greater than or equal to max(open, close) (#{max_price}) for label #{inspect(label)}"}

      low > min_price ->
        {:error, "low price (#{low}) must be less than or equal to min(open, close) (#{min_price}) for label #{inspect(label)}"}

      true ->
        :ok
    end
  end

  defp validate_item(item) do
    {:error, "invalid OHLC data item, expected map with :label, :open, :high, :low, :close: #{inspect(item)}"}
  end
end
