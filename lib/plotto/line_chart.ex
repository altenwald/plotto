defmodule Plotto.LineChart do
  @moduledoc """
  A line chart: a single line connecting one point per data item.

  Use a line chart to show a trend across ordered categories — a metric over time,
  for example. Plotto's line charts render exactly one line; multi-series line charts
  (multiple lines on one chart) are not supported.

  ## Example

      data = [
        %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
        %{label: "Feb", value: 25}
      ]

      chart = Plotto.LineChart.new!(data, title: "Trend", colors: ["#4E79A7"])
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  """

  defstruct [:data, :opts]

  @typedoc """
  One data point: a category `:label`, its numeric `:value`, and optional `:attrs` —
  arbitrary attribute/value pairs (e.g. `"phx-click"`, `"data-*"`) copied verbatim onto
  the corresponding SVG/PNG element for that point (a small circle marker), without
  Plotto depending on Phoenix or LiveView in any way.
  """
  @type data_item :: %{
          required(:label) => String.t(),
          required(:value) => number(),
          optional(:attrs) => %{optional(String.t()) => String.t()}
        }

  @typedoc """
  Chart options, after defaults have been applied. Passed as a keyword list to
  `new/2`/`new!/2`; stored in this resolved map form on the chart struct
  (`t:t/0`'s `:opts` field).
  """
  @type options :: %{
          width: pos_integer(),
          height: pos_integer(),
          title: String.t() | nil,
          colors: [String.t()]
        }

  @type t :: %__MODULE__{data: [data_item()], opts: options()}

  @doc """
  Builds a line chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` is a list of `t:data_item/0` maps: each needs a `:label` (string) and a
  non-negative `:value` (number), and may include `:attrs` for per-point attribute
  passthrough (e.g. Phoenix LiveView's `phx-click`).

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings; only the *first* color is
      used, as the line's stroke color (line charts render a single line, so there's
      no cycling). Defaults to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.

  ## Examples

      iex> {:ok, chart} = Plotto.LineChart.new([%{label: "Jan", value: 10}])
      iex> chart.data
      [%{label: "Jan", value: 10}]

      iex> {:ok, chart} =
      ...>   Plotto.LineChart.new(
      ...>     [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}],
      ...>     title: "Trend",
      ...>     colors: ["#000000"]
      ...>   )
      iex> {chart.opts.title, chart.opts.colors}
      {"Trend", ["#000000"]}

      iex> Plotto.LineChart.new([])
      {:error, "data must not be empty"}

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
