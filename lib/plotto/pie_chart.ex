defmodule Plotto.PieChart do
  @moduledoc """
  A pie chart: renders proportional slices of a circle or donut ring, supporting
  single-series pies/donuts and multi-series concentric rings.

  Use a pie chart to show part-to-whole relationships across categories. Slices can
  display optional labels (`:percent`, `:value`, `:label`, or a custom callback),
  a legend in any of the 12 positions, or be rendered compactly via `inline: true`.

  ## Example

      data = [
        %{label: "Desktop", value: 58},
        %{label: "Mobile", value: 32},
        %{label: "Tablet", value: 10}
      ]

      chart =
        Plotto.PieChart.new!(
          data,
          title: "Traffic by Device",
          label: :percent,
          legend: :bottom_center,
          legend_orientation: :horizontal
        )

      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  """

  defstruct [:data, :opts]

  alias Plotto.Chart.Builder
  alias Plotto.PieData

  @typedoc """
  One slice item: a category `:label`, its non-negative numeric `:value`, optional
  `:color` override, and optional `:attrs` map copied onto the slice SVG element.
  """
  @type data_item :: %{
          required(:label) => String.t(),
          required(:value) => number(),
          optional(:color) => String.t(),
          optional(:attrs) => %{optional(String.t()) => String.t()}
        }

  @typedoc """
  One pie series: `:name` (required when there are 2+ series) and its list of
  `t:data_item/0` slices.
  """
  @type series :: %{
          required(:name) => String.t() | nil,
          required(:data) => [data_item()]
        }

  @typedoc """
  Chart options after defaults have been applied, stored on the chart struct's `:opts` field.
  """
  @type options :: %{
          width: pos_integer(),
          height: pos_integer(),
          inline: boolean(),
          title: String.t() | nil,
          colors: [String.t()],
          mode: :pie | :donut,
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
          label: boolean() | :label | :value | :percent | :percentage | :top | nil | function(),
          value_prefix: String.t() | nil,
          value_suffix: String.t() | nil
        }

  @typedoc """
  The pie chart struct.
  """
  @type t :: %__MODULE__{data: [series()], opts: options()}

  @doc """
  Builds a pie chart. Returns `{:ok, chart}` or `{:error, reason}`.

  `data` can be a flat list of `t:data_item/0` maps for a single pie/donut, or a list
  of `t:series/0` maps for concentric rings.

  ## Options

    * `:width` - chart width in pixels. Defaults to `600` (or `24` when `inline: true`).
    * `:height` - chart height in pixels. Defaults to `400` (or `24` when `inline: true`).
    * `:inline` - when `true`, renders a compact pie/donut without slice labels, title,
      or legend. Defaults to `false`.
    * `:mode` - `:pie` (solid center, default) or `:donut` (hollow center ring).
    * `:title` - optional chart title centered above the chart. Defaults to `nil`.
    * `:colors` - list of `"#RRGGBB"` hex colors assigned to each slice category.
      Defaults to `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.
    * `:label` - optional slice label: `:percent` (or `:percentage`), `:value`,
      `true` (`:label`), or a 1-2 arity callback function. Defaults to `false`.
    * `:legend` - optional legend position. Defaults to `nil`.
    * `:legend_orientation` - `:vertical` or `:horizontal`. Defaults to `:vertical`.
    * `:value_prefix` (or `:prefix`) - optional string prepended to values. Defaults to `nil`.
    * `:value_suffix` (or `:suffix`) - optional string appended to values. Defaults to `nil`.
    * `:tooltip` - `:data` (default), `:native`, `false`, or a 1-2 arity formatter function.

  ## Examples

      iex> {:ok, chart} = Plotto.PieChart.new([%{label: "A", value: 60}, %{label: "B", value: 40}])
      iex> {chart.data, chart.opts.mode}
      {[%{name: nil, data: [%{label: "A", value: 60}, %{label: "B", value: 40}]}], :pie}

      iex> {:ok, chart} = Plotto.PieChart.new([%{label: "A", value: 60}], mode: :donut)
      iex> chart.opts.mode
      :donut

      iex> Plotto.PieChart.new([])
      {:error, "data must not be empty"}

  """
  @spec new([data_item()] | [series()], keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(data, opts \\ []) do
    opts = apply_defaults(opts)

    case Keyword.get(opts, :mode) do
      mode when mode in [:pie, :donut] ->
        Builder.new(__MODULE__, data, opts, PieData)

      invalid ->
        {:error, "invalid pie chart mode, expected :pie or :donut, got: #{inspect(invalid)}"}
    end
  end

  @doc """
  Same as `new/2`, but returns the `t:t/0` struct directly and raises `ArgumentError`
  on invalid data or options.
  """
  @spec new!([data_item()] | [series()], keyword()) :: t()
  def new!(data, opts \\ []) do
    case new(data, opts) do
      {:ok, chart} -> chart
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp apply_defaults(opts) do
    opts = Keyword.put_new(opts, :mode, :pie)

    if Keyword.get(opts, :inline, false) == true do
      opts
      |> Keyword.put_new(:width, 24)
      |> Keyword.put_new(:height, 24)
    else
      opts
    end
  end
end
