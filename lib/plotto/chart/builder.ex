defmodule Plotto.Chart.Builder do
  @moduledoc false

  alias Plotto.{Data, Options}

  def new(module, data, opts, validator \\ Data) do
    with :ok <- validator.validate(data),
         :ok <- Options.validate(opts) do
      normalized_data =
        if function_exported?(validator, :normalize, 1), do: validator.normalize(data), else: data

      {:ok, struct(module, data: normalized_data, opts: Options.build(opts))}
    end
  end

  def new!(module, data, opts, validator \\ Data) do
    case new(module, data, opts, validator) do
      {:ok, chart} -> chart
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
