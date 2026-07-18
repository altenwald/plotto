defmodule Plotto.SVG.Renderer.Shared do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.{Axis, Theme}

  def svg_root(width, height, children) do
    Element.new(
      "svg",
      %{
        "xmlns" => "http://www.w3.org/2000/svg",
        "viewBox" => "0 0 #{width} #{height}",
        "width" => width,
        "height" => height
      },
      children
    )
  end

  def title_elements(nil, _width), do: []

  def title_elements(title, width) do
    [
      Element.new(
        "text",
        %{
          "x" => width / 2,
          "y" => Theme.title_font_size(),
          "text-anchor" => "middle",
          "font-size" => Theme.title_font_size(),
          "fill" => Theme.text_color()
        },
        [title]
      )
    ]
  end

  def axis_elements(bands, margin, plot_width, plot_height, max_value) do
    y_axis_line =
      Element.new("line", %{
        "x1" => margin.left,
        "y1" => margin.top,
        "x2" => margin.left,
        "y2" => margin.top + plot_height,
        "stroke" => Theme.axis_color()
      })

    x_axis_line =
      Element.new("line", %{
        "x1" => margin.left,
        "y1" => margin.top + plot_height,
        "x2" => margin.left + plot_width,
        "y2" => margin.top + plot_height,
        "stroke" => Theme.axis_color()
      })

    x_labels = Enum.map(bands, &x_label(&1, margin, plot_height))
    y_labels = Enum.map(Axis.ticks(max_value), &y_label(&1, margin, plot_height, max_value))

    [y_axis_line, x_axis_line] ++ x_labels ++ y_labels
  end

  defp x_label(band, margin, plot_height) do
    Element.new(
      "text",
      %{
        "x" => margin.left + band.x,
        "y" => margin.top + plot_height + Theme.font_size() + 4,
        "text-anchor" => "middle",
        "font-size" => Theme.font_size(),
        "fill" => Theme.text_color()
      },
      [band.label]
    )
  end

  defp y_label(tick, margin, plot_height, max_value) do
    y = margin.top + Axis.linear_scale(tick, max_value, plot_height)

    Element.new(
      "text",
      %{
        "x" => margin.left - 8,
        "y" => y + Theme.font_size() / 2,
        "text-anchor" => "end",
        "font-size" => Theme.font_size(),
        "fill" => Theme.text_color()
      },
      [format_tick(tick)]
    )
  end

  defp format_tick(tick) do
    if tick == trunc(tick) do
      Integer.to_string(trunc(tick))
    else
      :erlang.float_to_binary(tick / 1, decimals: 2)
    end
  end
end
