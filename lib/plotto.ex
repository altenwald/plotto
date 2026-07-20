defmodule Plotto do
  @moduledoc """
  Plotto generates SVG charts in pure Elixir.

  ## Example

      chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}], title: "Sales")
      svg = Plotto.to_svg!(chart)

  """

  alias Plotto.SVG.{Renderer, Serializer}
  alias Plotto.PNG.{Canvas, Encoder, Rasterizer}

  @doc """
  Renders a chart (`Plotto.BarChart` or `Plotto.LineChart`) to an SVG string.

  Returns `{:ok, svg}` on success or `{:error, reason}` if rendering fails.
  """
  @spec to_svg(struct()) :: {:ok, String.t()} | {:error, String.t()}
  def to_svg(chart) do
    {:ok, chart |> Renderer.render() |> Serializer.serialize()}
  rescue
    error -> {:error, Exception.message(error)}
  end

  @doc "Same as `to_svg/1`, but returns the SVG string directly and raises on failure."
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

  @doc "Same as `to_png/1`, but returns the PNG binary directly and raises on failure."
  @spec to_png!(struct()) :: binary()
  def to_png!(chart) do
    case to_png(chart) do
      {:ok, png} -> png
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
