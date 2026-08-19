defmodule Plotto.BarChart do
  @moduledoc """
  A bar chart: one or more series, each rendered as a group of bars per category,
  bar height proportional to `:value`.

  Use a bar chart to compare values across categories — sales per month, votes per
  candidate, and similar "one or more numbers per category" data. With multiple
  series, each category shows one bar per series, grouped side by side and colored
  per series (see `:colors`); a legend (see `:legend`) can label each series.

  ## Example

      data = [
        %{
          name: "Sales",
          data: [
            %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
            %{label: "Feb", value: 25}
          ]
        }
      ]

      chart = Plotto.BarChart.new!(data, title: "Sales", colors: ["#4E79A7"])
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  """

  defstruct [:data, :opts]

  @typedoc """
  One data point: a category `:label`, its numeric `:value`, and optional `:attrs` —
  arbitrary attribute/value pairs (e.g. `"phx-click"`, `"data-*"`) copied verbatim onto
  the corresponding SVG/PNG element for that bar, without Plotto depending on Phoenix
  or LiveView in any way.
  """
  @type data_item :: %{
          required(:label) => String.t(),
          required(:value) => number(),
          optional(:attrs) => %{optional(String.t()) => String.t()}
        }

  @typedoc """
  One data series: `:name` (required when there are 2+ series — see `new/2`) and its
  list of `t:data_item/0` points. All series in a chart must share identical,
  identically-ordered `:label`s across their `:data`.
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

  @type t :: %__MODULE__{data: [series()], opts: options()}

  @doc """
  Builds a bar chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` is a list of `t:series/0` maps — one or more series, each with a `:name`
  and a list of `t:data_item/0` points. All series must have identical,
  identically-ordered `:label`s; `:name` may be `nil` only when there is exactly one
  series (2+ series must each have a non-nil `:name`, since it's shown in the
  legend).

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings, cycled **per series** — all
      bars within one series share the same color (`Theme.color(colors, series_index)`).
      Defaults to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.
    * `:legend` - optional legend position: `:top_left`, `:top_right`, `:bottom_left`,
      or `:bottom_right`. Renders one swatch+name row per series (using each series'
      `:name`), stacked vertically. Defaults to `nil` (no legend).

  ## Examples

      iex> {:ok, chart} = Plotto.BarChart.new([%{name: "Sales", data: [%{label: "Jan", value: 10}]}])
      iex> chart.data
      [%{name: "Sales", data: [%{label: "Jan", value: 10}]}]

      iex> {:ok, chart} =
      ...>   Plotto.BarChart.new(
      ...>     [%{name: "Sales", data: [%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]}],
      ...>     title: "Sales",
      ...>     colors: ["#000000"]
      ...>   )
      iex> {chart.opts.title, chart.opts.colors}
      {"Sales", ["#000000"]}

      iex> {:ok, chart} =
      ...>   Plotto.BarChart.new(
      ...>     [%{name: "Sales", data: [%{label: "Jan", value: 10}]}],
      ...>     legend: :top_right
      ...>   )
      iex> chart.opts.legend
      :top_right

      iex> Plotto.BarChart.new([%{name: "Sales", data: [%{label: "Jan", value: 10}]}], legend: :middle)
      {:error, "invalid legend position, got: :middle"}

      iex> Plotto.BarChart.new([])
      {:error, "data must not be empty"}

      iex> data = [
      ...>   %{name: "Sales", data: [%{label: "Jan", value: 10}]},
      ...>   %{name: nil, data: [%{label: "Jan", value: 5}]}
      ...> ]
      iex> Plotto.BarChart.new(data)
      {:error, "series name is required when there are multiple series"}

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
