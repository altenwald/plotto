defmodule Plotto.LineChart do
  @moduledoc """
  A line chart: a single line connecting one point per data item.

  Use a line chart to show a trend across ordered categories — a metric over time,
  for example. `data` uses the same multi-series shape as `Plotto.BarChart`, but
  today only the **first** series is drawn — full multi-series line rendering
  (multiple lines) is planned for a future release; extra series are currently
  accepted (so both chart types share the same data validation) but ignored when
  rendering, including in the legend.

  ## Example

      data = [
        %{
          name: "Trend",
          data: [
            %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
            %{label: "Feb", value: 25}
          ]
        }
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
  One data series: `:name` (required when there are 2+ series — see `new/2`) and its
  list of `t:data_item/0` points. All series in a chart must share identical,
  identically-ordered `:label`s across their `:data`. Only the first series is
  currently drawn — see the moduledoc.
  """
  @type series :: %{
          required(:name) => String.t() | nil,
          required(:data) => [data_item()]
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
          colors: [String.t()],
          legend: :top_left | :top_right | :bottom_left | :bottom_right | nil
        }

  @typedoc """
  The line chart struct.
  """
  @type t :: %__MODULE__{data: [series()], opts: options()}

  @doc """
  Builds a line chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` is a list of `t:series/0` maps — see the moduledoc: only the first series
  is drawn today, but the validation rules (matching labels, `:name` required for
  2+ series) apply the same as for `Plotto.BarChart`.

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings; only the first color is
      used, as the (first/only-rendered series') line's stroke color. Defaults to
      `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.
    * `:legend` - optional legend position: `:top_left`, `:top_right`, `:bottom_left`,
      or `:bottom_right`. Renders one row for the first series' `:name` only.
      Defaults to `nil` (no legend).

  ## Examples

      iex> {:ok, chart} = Plotto.LineChart.new([%{name: "Trend", data: [%{label: "Jan", value: 10}]}])
      iex> chart.data
      [%{name: "Trend", data: [%{label: "Jan", value: 10}]}]

      iex> {:ok, chart} =
      ...>   Plotto.LineChart.new(
      ...>     [%{name: "Trend", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}],
      ...>     title: "Trend",
      ...>     colors: ["#000000"]
      ...>   )
      iex> {chart.opts.title, chart.opts.colors}
      {"Trend", ["#000000"]}

      iex> {:ok, chart} =
      ...>   Plotto.LineChart.new(
      ...>     [%{name: "Trend", data: [%{label: "Jan", value: 10}]}],
      ...>     legend: :top_right
      ...>   )
      iex> chart.opts.legend
      :top_right

      iex> Plotto.LineChart.new([%{name: "Trend", data: [%{label: "Jan", value: 10}]}], legend: :middle)
      {:error, "invalid legend position, got: :middle"}

      iex> Plotto.LineChart.new([])
      {:error, "data must not be empty"}

  """
  @spec new([series()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  @spec new!([series()], keyword()) :: t()
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
