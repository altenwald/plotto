defmodule Plotto.CandlestickChart do
  @moduledoc """
  A candlestick chart: renders open-high-low-close (OHLC) financial and price
  data intervals as candlesticks with wicks and colored bodies.

  Use a candlestick chart to visualize asset prices, stock movements, and trading
  volatility over time intervals (minutes, hours, days, months).

  ## Example

      data = [
        %{label: "09:00", open: 100.0, high: 105.0, low: 98.0, close: 104.0},
        %{label: "09:05", open: 104.0, high: 106.0, low: 101.0, close: 102.0}
      ]

      chart = Plotto.CandlestickChart.new!(data, title: "AAPL - 5m")
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  """

  defstruct [:data, :opts]

  alias Plotto.CandlestickData
  alias Plotto.Chart.Builder

  @typedoc """
  One OHLC data point: interval `:label`, numeric `:open`, `:high`, `:low`, `:close`,
  and optional `:attrs` attribute map.
  """
  @type ohlc_item :: %{
          required(:label) => String.t(),
          required(:open) => number(),
          required(:high) => number(),
          required(:low) => number(),
          required(:close) => number(),
          optional(:attrs) => %{optional(String.t()) => String.t()}
        }

  @typedoc """
  One candlestick series: optional `:name` and its list of `t:ohlc_item/0` points.
  """
  @type series :: %{
          required(:name) => String.t() | nil,
          required(:data) => [ohlc_item()]
        }

  @typedoc """
  Chart options, after defaults have been applied. Stored in this resolved map
  form on the chart struct (`t:t/0`'s `:opts` field).
  """
  @type options :: %{
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          colors: [String.t()],
          legend:
            :top_left
            | :left_top
            | :top_right
            | :right_top
            | :bottom_left
            | :left_bottom
            | :bottom_right
            | :right_bottom
            | nil,
          bullish_color: String.t(),
          bearish_color: String.t(),
          tooltip: :data | :native | :title | false | nil | function()
        }

  @typedoc """
  The candlestick chart struct.
  """
  @type t :: %__MODULE__{data: [series()], opts: options()}

  @doc """
  Builds a candlestick chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` can be either a flat list of `t:ohlc_item/0` maps or a list of `t:series/0`
  maps containing OHLC points.

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title centered above the plot. Defaults to `nil`.
    * `:bullish_color` - hex color for bullish candles (`close >= open`). Defaults to `"#26A69A"`.
    * `:bearish_color` - hex color for bearish candles (`close < open`). Defaults to `"#EF5350"`.
    * `:legend` - optional legend position: `:top_left`, `:left_top`, `:top_right`,
      `:right_top`, `:bottom_left`, `:left_bottom`, `:bottom_right`, or `:right_bottom`.
      Defaults to `nil`.

  """
  @spec new([ohlc_item()] | [series()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(data, opts \\ []) do
    Builder.new(__MODULE__, data, opts, CandlestickData)
  end

  @doc """
  Same as `new/2`, but returns the `t:t/0` struct directly and raises `ArgumentError`
  if validation fails.
  """
  @spec new!([ohlc_item()] | [series()], keyword()) :: t()
  def new!(data, opts \\ []) do
    Builder.new!(__MODULE__, data, opts, CandlestickData)
  end
end
