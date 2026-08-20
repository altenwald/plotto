defmodule Plotto.SVG.Renderer do
  @moduledoc false

  def render(%Plotto.BarChart{} = chart), do: Plotto.SVG.Renderer.BarChart.render(chart)
  def render(%Plotto.LineChart{} = chart), do: Plotto.SVG.Renderer.LineChart.render(chart)

  def render(%Plotto.CandlestickChart{} = chart),
    do: Plotto.SVG.Renderer.CandlestickChart.render(chart)
end
