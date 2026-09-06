defmodule Plotto.LineChart do
  @moduledoc """
  A line chart: lines connecting points per data item across ordered categories.

  Use a line chart to show a trend across ordered categories — metrics over time,
  for example. Both single-series and multi-series charts are supported. Lines can
  be solid or dashed (via `:dashed => true`, `:style => :dashed`, `:stroke_dasharray`,
  or the `:line_styles` chart option), each series can have its own color, and series
  can span subsets of the shared category axis.

  ## Example

      data = [
        %{
          name: "Trend",
          data: [
            %{label: "Jan", value: 10, attrs: %{"phx-click" => "select", "phx-value-id" => "1"}},
            %{label: "Feb", value: 25}
          ]
        },
        %{
          name: "Target",
          dashed: true,
          data: [
            %{label: "Jan", value: 15},
            %{label: "Feb", value: 20}
          ]
        }
      ]

      chart = Plotto.LineChart.new!(data, title: "Trend vs Target", legend: :top_right)
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  """

  defstruct [:data, :opts]

  alias Plotto.Chart.Builder
  alias Plotto.LineData

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
  list of `t:data_item/0` points. Series can also specify `:dashed` (`true`/`false`),
  `:style` (`:solid`/`:dashed`), `:stroke_dasharray` (e.g. `"6,4"`), or `:color` (hex string).
  """
  @type series :: %{
          required(:name) => String.t() | nil,
          required(:data) => [data_item()],
          optional(:dashed) => boolean(),
          optional(:dotted) => boolean(),
          optional(:style) => :solid | :dashed | :dotted,
          optional(:stroke_dasharray) => String.t(),
          optional(:stroke_width) => number(),
          optional(:line_width) => number(),
          optional(:color) => String.t()
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
          tooltip: :data | :native | :title | false | nil | function(),
          label: boolean() | :label | :value | :top | nil | function(),
          line_styles: [atom() | String.t() | nil],
          stroke_width: number(),
          y_max: number() | nil,
          y_min: number() | nil,
          y_max_soft: boolean(),
          y_min_soft: boolean(),
          y_max_guide: false | {:solid | :dashed | :dotted, String.t()},
          y_min_guide: false | {:solid | :dashed | :dotted, String.t()},
          value_prefix: String.t() | nil,
          value_suffix: String.t() | nil,
          x_guidelines: false | {:solid | :dashed | :dotted, String.t()},
          y_guidelines: false | {:solid | :dashed | :dotted, String.t()}
        }

  @typedoc """
  The line chart struct.
  """
  @type t :: %__MODULE__{data: [series()], opts: options()}

  @doc """
  Builds a line chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` can be either a flat list of `t:data_item/0` maps or a list of `t:series/0` maps.

  ## Options

    * `:width` - chart width in pixels. Defaults to `600`.
    * `:height` - chart height in pixels. Defaults to `400`.
    * `:title` - optional chart title, centered above the plot. Defaults to `nil` (no
      title).
    * `:colors` - list of `"#RRGGBB"` hex color strings assigned to each series in order.
      Defaults to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.
    * `:legend` - optional legend position: `:top_left`, `:top_center`, `:top_right`,
      `:left_top`, `:left_middle`, `:left_bottom`, `:right_top`, `:right_middle`, `:right_bottom`,
      `:bottom_left`, `:bottom_center`, or `:bottom_right`. Defaults to `nil` (no legend).
    * `:legend_orientation` - optional legend layout orientation: `:vertical` or `:horizontal`.
      Applies when `:legend` is a top or bottom position. Defaults to `:vertical`.
    * `:line_styles` - optional list of styles (`:solid`, `:dashed`, `:dotted`, or custom dash pattern
      strings like `"6,4"`) corresponding to each series. Defaults to `[]`.
    * `:stroke_width` - optional stroke width in pixels for lines. Defaults to `1.5`.
      Can also be passed as `:line_width`, or specified per series.
    * `:label` - optional point label placed immediately above each point. When `true`
      (or `:label`), displays the point's `:label`. Can also be `:value` to display the
      numeric value, or a custom 1-2 arity function `(item)` or `(item, series_name)`.
      Defaults to `false` (no label above points).
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
    * `:x_guidelines` - optional vertical guidelines drawn at each category: `false`, `true`,
      or `{:solid | :dashed | :dotted, color}`. Defaults to `false`.
    * `:y_guidelines` - optional horizontal guidelines drawn at each Y-axis tick: `false`, `true`,
      or `{:solid | :dashed | :dotted, color}`. Defaults to `false`.

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
  @spec new([data_item()] | [series()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(data, opts \\ []), do: Builder.new(__MODULE__, data, opts, LineData)

  @doc """
  Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an
  error tuple. See `new/2` for the accepted `data` shape and available options.
  """
  @spec new!([data_item()] | [series()], keyword()) :: t()
  def new!(data, opts \\ []), do: Builder.new!(__MODULE__, data, opts, LineData)
end
