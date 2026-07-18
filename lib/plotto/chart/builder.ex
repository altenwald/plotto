defmodule Plotto.Chart.Builder do
  @moduledoc false

  alias Plotto.{Data, Options}

  def new(module, data, opts) do
    case Data.validate(data) do
      :ok -> {:ok, struct(module, data: data, opts: Options.build(opts))}
      {:error, _reason} = error -> error
    end
  end

  def new!(module, data, opts) do
    case new(module, data, opts) do
      {:ok, chart} -> chart
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
