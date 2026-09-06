defmodule Plotto.Options do
  @moduledoc false

  alias Plotto.Theme

  @modes [:grouped, :stacked]

  def modes, do: @modes

  def build(opts) do
    %{
      width: Keyword.get(opts, :width, Theme.default_width()),
      height: Keyword.get(opts, :height, Theme.default_height()),
      title: Keyword.get(opts, :title),
      colors: Keyword.get(opts, :colors, Theme.default_colors()),
      legend: Keyword.get(opts, :legend),
      legend_orientation: Keyword.get(opts, :legend_orientation, :vertical),
      mode: Keyword.get(opts, :mode, :grouped),
      bullish_color: Keyword.get(opts, :bullish_color, Theme.bullish_color()),
      bearish_color: Keyword.get(opts, :bearish_color, Theme.bearish_color()),
      tooltip: Keyword.get(opts, :tooltip, :data),
      label: Keyword.get(opts, :label, Keyword.get(opts, :labels, false)),
      line_styles:
        normalize_line_styles(Keyword.get(opts, :line_styles, Keyword.get(opts, :line_style, []))),
      stroke_width:
        Keyword.get(opts, :stroke_width, Keyword.get(opts, :line_width, Theme.stroke_width())),
      y_max: Keyword.get(opts, :y_max),
      y_min: Keyword.get(opts, :y_min),
      y_max_soft: Keyword.get(opts, :y_max_soft, true),
      y_min_soft: Keyword.get(opts, :y_min_soft, false),
      y_max_guide: normalize_guide(Keyword.get(opts, :y_max_guide, false)),
      y_min_guide: normalize_guide(Keyword.get(opts, :y_min_guide, false)),
      value_prefix: Keyword.get(opts, :value_prefix, Keyword.get(opts, :prefix)),
      value_suffix: Keyword.get(opts, :value_suffix, Keyword.get(opts, :suffix)),
      x_guidelines: normalize_guidelines(Keyword.get(opts, :x_guidelines, false)),
      y_guidelines: normalize_guidelines(Keyword.get(opts, :y_guidelines, false))
    }
  end

  def validate(opts) do
    with :ok <- validate_legend(Keyword.get(opts, :legend)),
         :ok <- validate_legend_orientation(Keyword.get(opts, :legend_orientation)),
         :ok <- validate_mode(Keyword.get(opts, :mode)),
         :ok <- validate_tooltip(Keyword.get(opts, :tooltip)),
         :ok <- validate_label(Keyword.get(opts, :label, Keyword.get(opts, :labels))),
         :ok <-
           validate_line_styles(Keyword.get(opts, :line_styles, Keyword.get(opts, :line_style))),
         :ok <-
           validate_stroke_width(Keyword.get(opts, :stroke_width, Keyword.get(opts, :line_width))),
         :ok <- validate_y_bounds(Keyword.get(opts, :y_min), Keyword.get(opts, :y_max)),
         :ok <- validate_boolean(:y_max_soft, Keyword.get(opts, :y_max_soft, true)),
         :ok <- validate_boolean(:y_min_soft, Keyword.get(opts, :y_min_soft, false)),
         :ok <- validate_guide(:y_max_guide, Keyword.get(opts, :y_max_guide, false)),
         :ok <- validate_guide(:y_min_guide, Keyword.get(opts, :y_min_guide, false)),
         :ok <- validate_guide(:x_guidelines, Keyword.get(opts, :x_guidelines, false)),
         :ok <- validate_guide(:y_guidelines, Keyword.get(opts, :y_guidelines, false)),
         :ok <-
           validate_string_or_nil(
             :value_prefix,
             Keyword.get(opts, :value_prefix, Keyword.get(opts, :prefix))
           ) do
      validate_string_or_nil(
        :value_suffix,
        Keyword.get(opts, :value_suffix, Keyword.get(opts, :suffix))
      )
    end
  end

  defp validate_legend(nil), do: :ok

  defp validate_legend(position) do
    if position in Theme.legend_positions() do
      :ok
    else
      {:error, "invalid legend position, got: #{inspect(position)}"}
    end
  end

  defp validate_legend_orientation(nil), do: :ok

  defp validate_legend_orientation(orient) when orient in [:vertical, :horizontal], do: :ok

  defp validate_legend_orientation(invalid) do
    {:error,
     "invalid legend_orientation option, expected :vertical or :horizontal, got: #{inspect(invalid)}"}
  end

  defp validate_mode(nil), do: :ok

  defp validate_mode(mode) do
    if mode in @modes do
      :ok
    else
      {:error, "invalid bar chart mode, got: #{inspect(mode)}"}
    end
  end

  defp validate_tooltip(nil), do: :ok
  defp validate_tooltip(false), do: :ok
  defp validate_tooltip(mode) when mode in [:data, :native, :title], do: :ok
  defp validate_tooltip(fun) when is_function(fun, 1) or is_function(fun, 2), do: :ok

  defp validate_tooltip(invalid) do
    {:error,
     "invalid tooltip option, expected :data, :native, :title, false, or a 1-2 arity function, got: #{inspect(invalid)}"}
  end

  defp validate_label(nil), do: :ok
  defp validate_label(false), do: :ok
  defp validate_label(true), do: :ok
  defp validate_label(mode) when mode in [:label, :value, :top, :data], do: :ok
  defp validate_label(fun) when is_function(fun, 1) or is_function(fun, 2), do: :ok

  defp validate_label(invalid) do
    {:error,
     "invalid label option, expected true, false, :label, :value, :top, or a 1-2 arity function, got: #{inspect(invalid)}"}
  end

  defp normalize_line_styles(styles) when is_list(styles), do: styles
  defp normalize_line_styles(style) when is_atom(style) or is_binary(style), do: [style]
  defp normalize_line_styles(_), do: []

  defp validate_line_styles(nil), do: :ok

  defp validate_line_styles(styles) when is_list(styles) do
    if Enum.all?(styles, &(&1 in [:solid, :dashed, :dotted] or is_binary(&1) or is_nil(&1))) do
      :ok
    else
      {:error,
       "invalid line_styles option, expected a list of :solid, :dashed, :dotted, nil, or string dash patterns"}
    end
  end

  defp validate_line_styles(style) when is_atom(style) or is_binary(style) do
    validate_line_styles([style])
  end

  defp validate_line_styles(invalid) do
    {:error, "invalid line_styles option, expected a list, got: #{inspect(invalid)}"}
  end

  defp validate_stroke_width(nil), do: :ok
  defp validate_stroke_width(w) when is_number(w) and w > 0, do: :ok

  defp validate_stroke_width(invalid) do
    {:error, "invalid stroke_width option, expected a positive number, got: #{inspect(invalid)}"}
  end

  defp validate_y_bounds(nil, nil), do: :ok
  defp validate_y_bounds(y_min, nil) when is_number(y_min), do: :ok
  defp validate_y_bounds(nil, y_max) when is_number(y_max), do: :ok

  defp validate_y_bounds(y_min, y_max) when is_number(y_min) and is_number(y_max) do
    if y_min <= y_max do
      :ok
    else
      {:error, "y_min (#{y_min}) must be less than or equal to y_max (#{y_max})"}
    end
  end

  defp validate_y_bounds(y_min, _y_max) when not is_nil(y_min) and not is_number(y_min) do
    {:error, "invalid y_min option, expected a number, got: #{inspect(y_min)}"}
  end

  defp validate_y_bounds(_y_min, y_max) when not is_nil(y_max) and not is_number(y_max) do
    {:error, "invalid y_max option, expected a number, got: #{inspect(y_max)}"}
  end

  defp validate_boolean(_name, val) when is_boolean(val), do: :ok

  defp validate_boolean(name, invalid) do
    {:error, "invalid #{name} option, expected a boolean, got: #{inspect(invalid)}"}
  end

  @valid_guide_styles [:solid, :dashed, :dotted]

  defp normalize_guide(false), do: false
  defp normalize_guide(nil), do: false
  defp normalize_guide(true), do: {:dashed, Theme.axis_color()}

  defp normalize_guide({style, color}) when is_binary(color) and style in @valid_guide_styles,
    do: {style, color}

  defp normalize_guide(color) when is_binary(color), do: {:dashed, color}
  defp normalize_guide(other), do: other

  defp normalize_guidelines(false), do: false
  defp normalize_guidelines(nil), do: false
  defp normalize_guidelines(true), do: {:dotted, Theme.grid_color()}

  defp normalize_guidelines({style, color})
       when is_binary(color) and style in @valid_guide_styles,
       do: {style, color}

  defp normalize_guidelines(color) when is_binary(color), do: {:dotted, color}
  defp normalize_guidelines(other), do: other

  defp validate_guide(_name, false), do: :ok
  defp validate_guide(_name, nil), do: :ok
  defp validate_guide(_name, true), do: :ok
  defp validate_guide(_name, color) when is_binary(color), do: :ok

  defp validate_guide(_name, {style, color})
       when style in @valid_guide_styles and is_binary(color),
       do: :ok

  defp validate_guide(name, invalid) do
    {:error,
     "invalid #{name} option, expected false, true, a color string, or {:solid | :dashed | :dotted, color}, got: #{inspect(invalid)}"}
  end

  defp validate_string_or_nil(_name, nil), do: :ok
  defp validate_string_or_nil(_name, val) when is_binary(val), do: :ok

  defp validate_string_or_nil(name, invalid) do
    {:error, "invalid #{name} option, expected a string or nil, got: #{inspect(invalid)}"}
  end
end
