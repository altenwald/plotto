defmodule Plotto.Chart.Builder do
  @moduledoc false

  alias Plotto.{Data, Options}

  def new(module, data, opts) do
    with :ok <- Data.validate(data),
         :ok <- Options.validate(opts) do
      {:ok, struct(module, data: data, opts: Options.build(opts))}
    end
  end

  def new!(module, data, opts) do
    case new(module, data, opts) do
      {:ok, chart} -> chart
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
