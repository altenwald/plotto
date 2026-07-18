defmodule Plotto.Data do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    case Enum.find_value(data, &item_error/1) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

  defp item_error(%{label: label, value: value}) when is_binary(label) and is_number(value) do
    if value < 0 do
      "value must not be negative, got: #{inspect(value)} for label #{inspect(label)}"
    else
      nil
    end
  end

  defp item_error(item) do
    "invalid data item, expected a map with :label (string) and :value (number), got: #{inspect(item)}"
  end
end
