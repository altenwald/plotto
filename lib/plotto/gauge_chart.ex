defmodule Plotto.GaugeChart do
  @moduledoc """
  A gauge chart: renders one or more horseshoe (240°) progress arcs with a neutral
  border, transparent unfilled track, and centered numeric values.

  Use a gauge chart to display key metrics such as CPU load, speed, RPM, or goal
  completion. A single value supports threshold color zones (`:thresholds`), while
  multiple values render as concentric horseshoe arcs with fixed per-series colors.

  ## Example

      # Single-value gauge with threshold color zones
      chart =
        Plotto.GaugeChart.new!(
          %{label: "CPU Load", value: 78},
          title: "Server Load",
          suffix: "%",
          thresholds: [{60, "#2ECC71"}, {85, "#F1C40F"}, {100, "#E74C3C"}]
        )

      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

      # Multi-value concentric gauge
      multi =
        Plotto.GaugeChart.new!(
          [
            %{label: "CPU", value: 78},
            %{label: "Memory", value: 62},
            %{label: "Disk", value: 45}
          ],
          title: "System Resources",
          suffix: "%",
          legend: :bottom_center,
          legend_orientation: :horizontal
        )

  """

  defstruct [:data, :opts]

  alias Plotto.Chart.Builder
  alias Plotto.GaugeData

  @typedoc """
  One gauge item: an optional `:label`, its numeric `:value`, optional `:color` override,
  and optional `:attrs` map copied onto the filled arc SVG element.
  """
  @type gauge_item :: %{
          required(:label) => String.t() | nil,
          required(:value) => number(),
          optional(:color) => String.t(),
          optional(:attrs) => %{optional(String.t()) => String.t()}
        }

  @typedoc """
  A color threshold zone defined as `{upper_bound, hex_color}` or
  `%{to: upper_bound, color: hex_color}`.
  """
  @type threshold ::
          {number(), String.t()}
          | %{required(:to) => number(), required(:color) => String.t()}

  @typedoc """
  Chart options after defaults have been applied, stored on the chart struct's `:opts` field.
  """
  @type options :: %{
          width: pos_integer(),
          height: pos_integer(),
          inline: boolean(),
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
          thresholds: :default | [{number(), String.t()}],
          y_max: number() | nil,
          y_min: number() | nil,
          y_max_soft: boolean(),
          y_min_soft: boolean(),
          value_prefix: String.t() | nil,
          value_suffix: String.t() | nil
        }

  @typedoc """
  The gauge chart struct.
  """
  @type t :: %__MODULE__{data: [gauge_item()], opts: options()}

  @doc """
  Builds a gauge chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` can be a single number (e.g. `75`), a map with `:value` (and optional `:label`,
  `:color`, `:attrs`), or a non-empty list of gauge items for concentric arcs.

  ## Options

    * `:width` - chart width in pixels. Defaults to `600` (or `32` when `inline: true`).
    * `:height` - chart height in pixels. Defaults to `400` (or `24` when `inline: true`).
    * `:inline` - when `true`, renders a compact gauge without center text, min/max labels,
      title, or legend for embedding inline within text or table cells. Defaults to `false`.
    * `:title` - optional chart title centered above the gauge. Defaults to `nil`.
    * `:colors` - list of `"#RRGGBB"` hex colors assigned to each concentric arc.
      Defaults to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.
    * `:thresholds` (or `:zones`) - threshold color zones for a single-value gauge:
      `true` for default green/yellow/red zones (60% / 85% / 100%), or a list of
      `{upper_bound, color}` tuples / `%{to: upper_bound, color: color}` maps.
      Defaults to `[]`.
    * `:min` (or `:y_min`) - minimum gauge value. Defaults to `0` (or lower if data is negative).
    * `:max` (or `:y_max`) - maximum gauge value. Defaults to `100` (or higher if data exceeds `100`).
    * `:legend` - optional legend position. Defaults to `nil`.
    * `:legend_orientation` - `:vertical` or `:horizontal`. Defaults to `:vertical`.
    * `:value_prefix` (or `:prefix`) - optional string prepended to values. Defaults to `nil`.
    * `:value_suffix` (or `:suffix`) - optional string appended to values. Defaults to `nil`.
    * `:tooltip` - `:data` (default), `:native`, `false`, or a 1-2 arity formatter function.

  ## Examples

      iex> {:ok, chart} = Plotto.GaugeChart.new(75, suffix: "%")
      iex> chart.data
      [%{label: nil, value: 75}]

      iex> {:ok, chart} = Plotto.GaugeChart.new(%{label: "CPU", value: 80}, thresholds: true)
      iex> {chart.data, chart.opts.thresholds}
      {[%{label: "CPU", value: 80}], :default}

      iex> Plotto.GaugeChart.new([])
      {:error, "data must not be empty"}

  """
  @spec new(number() | map() | [number() | map()], keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def new(data, opts \\ []) do
    Builder.new(__MODULE__, data, apply_inline_defaults(opts), GaugeData)
  end

  @doc """
  Same as `new/2`, but returns the `t:t/0` struct directly and raises `ArgumentError`
  on invalid data or options.
  """
  @spec new!(number() | map() | [number() | map()], keyword()) :: t()
  def new!(data, opts \\ []) do
    Builder.new!(__MODULE__, data, apply_inline_defaults(opts), GaugeData)
  end

  defp apply_inline_defaults(opts) do
    if Keyword.get(opts, :inline, false) == true do
      opts
      |> Keyword.put_new(:width, 32)
      |> Keyword.put_new(:height, 24)
    else
      opts
    end
  end
end
