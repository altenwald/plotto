defmodule Plotto.GaugeData do
  @moduledoc false

  def validate(value) when is_number(value), do: :ok

  def validate(%{} = item) do
    validate_item(item)
  end

  def validate(data) when is_list(data) and data != [] do
    Enum.find_value(data, :ok, fn item ->
      case validate_list_item(item) do
        :ok -> nil
        error -> error
      end
    end)
  end

  def validate([]), do: {:error, "data must not be empty"}

  def validate(_data) do
    {:error, "data must be a number, a map with :value, or a non-empty list of gauge items"}
  end

  def normalize(value) when is_number(value) do
    [%{label: nil, value: value}]
  end

  def normalize(%{} = item) do
    [normalize_item(item)]
  end

  def normalize(data) when is_list(data) do
    Enum.map(data, &normalize_item/1)
  end

  defp validate_list_item(value) when is_number(value), do: :ok
  defp validate_list_item(%{} = item), do: validate_item(item)

  defp validate_list_item(item) do
    {:error,
     "invalid gauge item, expected a number or a map with :value (number), got: #{inspect(item)}"}
  end

  defp validate_item(%{value: value} = item) when is_number(value) do
    label = Map.get(item, :label, Map.get(item, :name))
    color = Map.get(item, :color)
    attrs = Map.get(item, :attrs)

    cond do
      not (is_nil(label) or is_binary(label)) ->
        {:error, "invalid gauge item :label, expected a string or nil, got: #{inspect(label)}"}

      not (is_nil(color) or is_binary(color)) ->
        {:error,
         "invalid gauge item :color, expected a color string or nil, got: #{inspect(color)}"}

      not (is_nil(attrs) or is_map(attrs)) ->
        {:error, "invalid gauge item :attrs, expected a map or nil, got: #{inspect(attrs)}"}

      true ->
        :ok
    end
  end

  defp validate_item(item) do
    {:error, "invalid gauge item, expected a map with numeric :value, got: #{inspect(item)}"}
  end

  defp normalize_item(value) when is_number(value) do
    %{label: nil, value: value}
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
end
