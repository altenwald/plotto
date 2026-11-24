defmodule Plotto.SVG.Renderer do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.Theme

  def render(chart) do
    chart |> render_chart() |> apply_theme(chart.opts)
  end

  defp render_chart(%Plotto.BarChart{} = chart), do: Plotto.SVG.Renderer.BarChart.render(chart)
  defp render_chart(%Plotto.LineChart{} = chart), do: Plotto.SVG.Renderer.LineChart.render(chart)

  defp render_chart(%Plotto.CandlestickChart{} = chart),
    do: Plotto.SVG.Renderer.CandlestickChart.render(chart)

  defp render_chart(%Plotto.GaugeChart{} = chart),
    do: Plotto.SVG.Renderer.GaugeChart.render(chart)

  defp render_chart(%Plotto.PieChart{} = chart),
    do: Plotto.SVG.Renderer.PieChart.render(chart)

  # `theme: :css`: the colors of text, axes and grid become CSS variables (`--plotto-text`, `--plotto-axis`,
  # `--plotto-grid`) with the default color as fallback, so the page decides the theme and it can change without
  # drawing the chart again. They go in `style` because it wins over the `fill`/`stroke` attributes.
  defp apply_theme(%Element{} = tree, %{theme: :css}) do
    vars = %{
      Theme.text_color() => "--plotto-text",
      Theme.axis_color() => "--plotto-axis",
      Theme.grid_color() => "--plotto-grid"
    }

    themed(tree, vars)
  end

  defp apply_theme(tree, _opts), do: tree

  defp themed(%Element{attrs: attrs, children: children} = element, vars) do
    style =
      for {attr, css} <- [{"fill", "fill"}, {"stroke", "stroke"}],
          color = Map.get(attrs, attr),
          var = Map.get(vars, color),
          do: "#{css}:var(#{var},#{color})"

    attrs =
      case style do
        [] ->
          attrs

        parts ->
          Map.update(attrs, "style", Enum.join(parts, ";"), &(&1 <> ";" <> Enum.join(parts, ";")))
      end

    %{element | attrs: attrs, children: Enum.map(children, &themed(&1, vars))}
  end

  defp themed(text, _vars) when is_binary(text), do: text
end
