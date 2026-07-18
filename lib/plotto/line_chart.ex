defmodule Plotto.LineChart do
  @moduledoc """
  A line chart: a single line connecting one point per data item.
  """

  defstruct [:data, :opts]

  @type t :: %__MODULE__{data: [map()], opts: map()}

  @doc """
  Builds a line chart. Returns `{:ok, chart}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, chart} = Plotto.LineChart.new([%{label: "Jan", value: 10}])
      iex> chart.data
      [%{label: "Jan", value: 10}]

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc "Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an error tuple."
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
