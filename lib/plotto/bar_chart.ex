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
          legend:
            :top_left
            | :top_center
            | :top_right
            | :left_top
            | :left_middle
            | :left_bottom
            | :right_top
            | :right_middle
            | :right_bottom
            | :bottom_left
            | :bottom_center
            | :bottom_right
            | :top
            | :bottom
            | nil,
          legend_orientation: :vertical | :horizontal,
          mode: :grouped | :stacked,
          tooltip: :data | :native | :title | false | nil | function(),
          label: boolean() | :label | :value | :top | nil | function(),
          y_max: number() | nil,
          y_min: number() | nil,
          y_max_soft: boolean(),
          y_min_soft: boolean(),
          y_max_guide: false | {:solid | :dashed | :dotted, String.t()},
          y_min_guide: false | {:solid | :dashed | :dotted, String.t()},
          value_prefix: String.t() | nil,
          value_suffix: String.t() | nil
        }

  @typedoc """
  The bar chart struct.
  """
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
    * `:legend` - optional legend position: `:top_left`, `:top_center`, `:top_right`,
      `:left_top`, `:left_middle`, `:left_bottom`, `:right_top`, `:right_middle`, `:right_bottom`,
      `:bottom_left`, `:bottom_center`, or `:bottom_right`. Defaults to `nil` (no legend).
    * `:legend_orientation` - optional legend layout orientation: `:vertical` or `:horizontal`.
      Applies when `:legend` is a top or bottom position. Defaults to `:vertical`.
    * `:mode` - bar chart layout mode: `:grouped` (bars per series side by side) or
      `:stacked` (bars per series stacked vertically summing the total). Defaults to
      `:grouped`.
    * `:label` - optional bar label placed immediately above each bar. When `true`
      (or `:label`), displays the point's `:label`. Can also be `:value` to display the
      numeric value, or a custom 1-2 arity function `(item)` or `(item, series_name)`.
      Defaults to `false` (no label above bars).
    * `:y_max` - optional maximum target or upper bound for the Y axis. Defaults to `nil`.
    * `:y_min` - optional minimum target or lower bound for the Y axis. Defaults to `nil`.
    * `:y_max_soft` - boolean indicating if `:y_max` can be exceeded if data values are greater.
      Defaults to `true`.
    * `:y_min_soft` - boolean indicating if `:y_min` can be exceeded if data values are smaller.
      Defaults to `false`.
    * `:y_max_guide` - optional horizontal guide line drawn at `y_max`: `false`, `true`,
      or `{:solid | :dashed | :dotted, color}`. Defaults to `false`.
    * `:y_min_guide` - optional horizontal guide line drawn at `y_min`: `false`, `true`,
      or `{:solid | :dashed | :dotted, color}`. Defaults to `false`.
    * `:value_prefix` - optional string prefix prepended to numeric values (e.g. `"$"`, `"€"`).
      Can also be passed as `:prefix`. Defaults to `nil`.
    * `:value_suffix` - optional string suffix appended to numeric values (e.g. `"%"`).
      Can also be passed as `:suffix`. Defaults to `nil`.

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
  @spec new([series()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  @spec new!([series()], keyword()) :: t()
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
