defmodule Plotto do
  @moduledoc """
  Plotto generates SVG and PNG charts in pure Elixir.

  ## Example

      chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}], title: "Sales")
      svg = Plotto.to_svg!(chart)
      png = Plotto.to_png!(chart)

  ## Options

  Both `Plotto.BarChart` and `Plotto.LineChart` accept the same six options via
  `new/2`/`new!/2`: `:width`, `:height`, `:title`, `:colors`, `:name`, `:legend`. See
  `Plotto.BarChart.new/2` (or `Plotto.LineChart.new/2`) for their exact defaults and
  shapes — line charts differ slightly in how `:colors` is used (only the first color
  is applied, as the single line's stroke), documented there. `:name` and `:legend`
  together control an optional single-entry legend (a color swatch plus the series
  name), positioned in one of the chart's four corners.

  ## Error handling

  `to_svg/1` and `to_png/1` return `{:ok, result} | {:error, reason}` and never raise.
  `to_svg!/1` and `to_png!/1` return the result directly and raise `ArgumentError` if
  rendering fails.
  """

  alias Plotto.SVG.{Renderer, Serializer}
  alias Plotto.PNG.{Canvas, Encoder, Rasterizer}

  @doc """
  Renders a chart (`Plotto.BarChart` or `Plotto.LineChart`) to an SVG string.

  Returns `{:ok, svg}` on success or `{:error, reason}` if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> {:ok, svg} = Plotto.to_svg(chart)
      iex> String.starts_with?(svg, "<svg")
      true

  """
  @spec to_svg(struct()) :: {:ok, String.t()} | {:error, String.t()}
  def to_svg(chart) do
    {:ok, chart |> Renderer.render() |> Serializer.serialize()}
  rescue
    error -> {:error, Exception.message(error)}
  end

  @doc """
  Same as `to_svg/1`, but returns the SVG string directly and raises `ArgumentError`
  if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> Plotto.to_svg!(chart) |> String.starts_with?("<svg")
      true

  """
  @spec to_svg!(struct()) :: String.t()
  def to_svg!(chart) do
    case to_svg(chart) do
      {:ok, svg} -> svg
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Renders a chart (`Plotto.BarChart` or `Plotto.LineChart`) to a PNG binary.

  Returns `{:ok, png}` on success or `{:error, reason}` if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> {:ok, png} = Plotto.to_png(chart)
      iex> binary_part(png, 0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>
      true

  """
  @spec to_png(struct()) :: {:ok, binary()} | {:error, String.t()}
  def to_png(chart) do
    %{width: width, height: height} = chart.opts

    png =
      chart
      |> Renderer.render()
      |> Rasterizer.rasterize(width, height)
      |> Canvas.downsample(Rasterizer.supersample_factor())
      |> Encoder.encode()

    {:ok, png}
  rescue
    error -> {:error, Exception.message(error)}
  end

  @doc """
  Same as `to_png/1`, but returns the PNG binary directly and raises `ArgumentError`
  if rendering fails.

  ## Examples

      iex> chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}])
      iex> Plotto.to_png!(chart) |> binary_part(0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>
      true

  """
  @spec to_png!(struct()) :: binary()
  def to_png!(chart) do
    case to_png(chart) do
      {:ok, png} -> png
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
