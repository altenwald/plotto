defmodule Plotto.BarChart do
  @moduledoc """
  A bar chart: one bar per data item, bar height proportional to `:value`.
  """

  defstruct [:data, :opts]

  @type t :: %__MODULE__{data: [map()], opts: map()}

  @doc """
  Builds a bar chart. Returns `{:ok, chart}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, chart} = Plotto.BarChart.new([%{label: "Jan", value: 10}])
      iex> chart.data
      [%{label: "Jan", value: 10}]

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc "Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an error tuple."
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
