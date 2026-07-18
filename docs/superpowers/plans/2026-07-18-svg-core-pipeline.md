# SVG Core Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete SVG rendering pipeline for Plotto: bar charts and line charts, from typed data structs to a serialized SVG string, including per-data-point attribute passthrough (for LiveView-style `phx-*` attributes) and XML escaping.

**Architecture:** Chart structs (`Plotto.BarChart`, `Plotto.LineChart`) are built and validated via a shared `Plotto.Chart.Builder`. `Plotto.SVG.Renderer` turns a chart struct into an intermediate `Plotto.SVG.Element` tree (shared `Axis`/`Theme` helpers compute scales, ticks and colors). `Plotto.SVG.Serializer` walks that tree into an escaped XML string. `Plotto.to_svg/1` and `Plotto.to_svg!/1` wire it all together as the public API.

**Tech Stack:** Elixir ~> 1.17, ExUnit. No new dependencies — pure string/data manipulation.

**Related spec:** `docs/superpowers/specs/2026-07-17-core-chart-slice-design.md` (this plan covers the SVG half only; the PNG export pipeline is a separate plan).

---

## Conventions used throughout this plan

- Run a single test file with: `mix test path/to/file_test.exs`
- Run the whole suite with: `mix test`
- All new modules except `Plotto`, `Plotto.BarChart`, and `Plotto.LineChart` are internal (`@moduledoc false`) — they are implementation details, not part of the public API.
- Default chart canvas: `width: 600`, `height: 400`, margin `top: 40, right: 24, bottom: 48, left: 56`.
- Default color palette: `["#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F"]`.

---

### Task 1: `Plotto.Theme` — default styling constants

**Files:**
- Create: `lib/plotto/theme.ex`
- Test: `test/plotto/theme_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.ThemeTest do
  use ExUnit.Case, async: true

  alias Plotto.Theme

  test "default_colors/0 returns a non-empty list of hex colors" do
    colors = Theme.default_colors()
    assert is_list(colors)
    assert length(colors) > 0
    assert Enum.all?(colors, &String.starts_with?(&1, "#"))
  end

  test "default_width/0 and default_height/0 return positive integers" do
    assert Theme.default_width() > 0
    assert Theme.default_height() > 0
  end

  test "margin/0 returns a map with top/right/bottom/left keys" do
    margin = Theme.margin()
    assert %{top: _, right: _, bottom: _, left: _} = margin
  end

  test "color/2 cycles through the palette by index" do
    colors = ["#111111", "#222222"]
    assert Theme.color(colors, 0) == "#111111"
    assert Theme.color(colors, 1) == "#222222"
    assert Theme.color(colors, 2) == "#111111"
    assert Theme.color(colors, 3) == "#222222"
  end

  test "color/2 falls back to the default palette when given an empty list" do
    assert Theme.color([], 0) == List.first(Theme.default_colors())
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/theme_test.exs`
Expected: FAIL — `Plotto.Theme` module is undefined.

- [ ] **Step 3: Implement `Plotto.Theme`**

```elixir
defmodule Plotto.Theme do
  @moduledoc false

  @default_colors [
    "#4E79A7",
    "#F28E2B",
    "#E15759",
    "#76B7B2",
    "#59A14F"
  ]

  @default_width 600
  @default_height 400
  @margin %{top: 40, right: 24, bottom: 48, left: 56}
  @axis_color "#CCCCCC"
  @text_color "#333333"
  @font_size 12
  @title_font_size 18

  def default_colors, do: @default_colors
  def default_width, do: @default_width
  def default_height, do: @default_height
  def margin, do: @margin
  def axis_color, do: @axis_color
  def text_color, do: @text_color
  def font_size, do: @font_size
  def title_font_size, do: @title_font_size

  def color([], index), do: color(@default_colors, index)

  def color(colors, index) do
    Enum.at(colors, rem(index, length(colors)))
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/theme_test.exs`
Expected: PASS (5 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/theme.ex test/plotto/theme_test.exs
git commit --no-gpg-sign -m "Add Plotto.Theme with default styling constants"
```

---

### Task 2: `Plotto.Axis` — scales and ticks

**Files:**
- Create: `lib/plotto/axis.ex`
- Test: `test/plotto/axis_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.AxisTest do
  use ExUnit.Case, async: true

  alias Plotto.Axis

  describe "categorical_scale/2" do
    test "splits the plot width evenly into one band per label" do
      [a, b, c] = Axis.categorical_scale(["Jan", "Feb", "Mar"], 300)

      assert a == %{label: "Jan", band_x: 0.0, band_width: 100.0, x: 50.0}
      assert b == %{label: "Feb", band_x: 100.0, band_width: 100.0, x: 150.0}
      assert c == %{label: "Mar", band_x: 200.0, band_width: 100.0, x: 250.0}
    end

    test "works with a single label" do
      [only] = Axis.categorical_scale(["Solo"], 200)
      assert only == %{label: "Solo", band_x: 0.0, band_width: 200.0, x: 100.0}
    end
  end

  describe "linear_scale/3" do
    test "maps 0 to the bottom of the plot area" do
      assert Axis.linear_scale(0, 100, 200) == 200.0
    end

    test "maps the max value to the top of the plot area" do
      assert Axis.linear_scale(100, 100, 200) == 0.0
    end

    test "maps an intermediate value proportionally" do
      assert Axis.linear_scale(50, 100, 200) == 100.0
    end

    test "returns the bottom of the plot area when max_value is 0" do
      assert Axis.linear_scale(0, 0, 200) == 200.0
    end
  end

  describe "ticks/2" do
    test "generates count + 1 evenly spaced ticks from 0 to max_value" do
      assert Axis.ticks(100, 5) == [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]
    end

    test "defaults to 5 divisions" do
      assert Axis.ticks(10) == [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]
    end

    test "returns [0] when max_value is 0" do
      assert Axis.ticks(0) == [0]
    end
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/axis_test.exs`
Expected: FAIL — `Plotto.Axis` module is undefined.

- [ ] **Step 3: Implement `Plotto.Axis`**

```elixir
defmodule Plotto.Axis do
  @moduledoc false

  def categorical_scale(labels, plot_width) do
    band_width = plot_width / length(labels)

    labels
    |> Enum.with_index()
    |> Enum.map(fn {label, index} ->
      band_x = index * band_width
      %{label: label, band_x: band_x, band_width: band_width, x: band_x + band_width / 2}
    end)
  end

  def linear_scale(_value, 0, plot_height), do: plot_height / 1

  def linear_scale(value, max_value, plot_height) do
    plot_height - value / max_value * plot_height
  end

  def ticks(max_value, count \\ 5)
  def ticks(0, _count), do: [0]

  def ticks(max_value, count) do
    step = max_value / count
    for i <- 0..count, do: i * step
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/axis_test.exs`
Expected: PASS (9 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/axis.ex test/plotto/axis_test.exs
git commit --no-gpg-sign -m "Add Plotto.Axis with categorical/linear scales and ticks"
```

---

### Task 3: `Plotto.SVG.Element` — intermediate tree node

**Files:**
- Create: `lib/plotto/svg/element.ex`
- Test: `test/plotto/svg/element_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.SVG.ElementTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.Element

  test "new/3 defaults to no attrs and no children" do
    element = Element.new("svg")
    assert element.tag == "svg"
    assert element.attrs == %{}
    assert element.children == []
  end

  test "new/3 stringifies attr keys and integer/string values" do
    element = Element.new("rect", %{x: 10, "fill" => "#FF0000"})
    assert element.attrs == %{"x" => "10", "fill" => "#FF0000"}
  end

  test "new/3 formats float attr values with 2 decimals" do
    element = Element.new("rect", %{x: 10.5, y: 3.14159})
    assert element.attrs == %{"x" => "10.50", "y" => "3.14"}
  end

  test "new/3 keeps children as given" do
    child = Element.new("text", %{}, ["hello"])
    parent = Element.new("g", %{}, [child])
    assert parent.children == [child]
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/svg/element_test.exs`
Expected: FAIL — `Plotto.SVG.Element` module is undefined.

- [ ] **Step 3: Implement `Plotto.SVG.Element`**

```elixir
defmodule Plotto.SVG.Element do
  @moduledoc false

  defstruct tag: nil, attrs: %{}, children: []

  @type t :: %__MODULE__{
          tag: String.t(),
          attrs: %{optional(String.t()) => String.t()},
          children: [t() | String.t()]
        }

  def new(tag, attrs \\ %{}, children \\ []) do
    %__MODULE__{tag: tag, attrs: stringify_attrs(attrs), children: children}
  end

  defp stringify_attrs(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), format_value(v)} end)
  end

  defp format_value(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp format_value(v), do: to_string(v)
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/svg/element_test.exs`
Expected: PASS (4 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/svg/element.ex test/plotto/svg/element_test.exs
git commit --no-gpg-sign -m "Add Plotto.SVG.Element intermediate tree node"
```

---

### Task 4: `Plotto.SVG.Serializer` — XML serialization with escaping

**Files:**
- Create: `lib/plotto/svg/serializer.ex`
- Test: `test/plotto/svg/serializer_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.SVG.SerializerTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.{Element, Serializer}

  test "serializes an element with no children as self-closing" do
    element = Element.new("rect", %{x: 1, y: 2})
    assert Serializer.serialize(element) == ~s(<rect x="1" y="2"/>)
  end

  test "serializes an element with a text child" do
    element = Element.new("text", %{}, ["hello"])
    assert Serializer.serialize(element) == ~s(<text>hello</text>)
  end

  test "serializes nested elements" do
    child = Element.new("rect", %{x: 1})
    parent = Element.new("g", %{}, [child])
    assert Serializer.serialize(parent) == ~s(<g><rect x="1"/></g>)
  end

  test "sorts attributes alphabetically for deterministic output" do
    element = Element.new("rect", %{y: 2, x: 1, fill: "red"})
    assert Serializer.serialize(element) == ~s(<rect fill="red" x="1" y="2"/>)
  end

  test "escapes &, < and > in text content" do
    element = Element.new("text", %{}, ["a < b & c > d"])
    assert Serializer.serialize(element) == ~s(<text>a &lt; b &amp; c &gt; d</text>)
  end

  test "escapes &, <, > and \" in attribute values" do
    element = Element.new("rect", %{"data-label" => ~s(a "b" & <c>)})
    assert Serializer.serialize(element) ==
             ~s(<rect data-label="a &quot;b&quot; &amp; &lt;c&gt;"/>)
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/svg/serializer_test.exs`
Expected: FAIL — `Plotto.SVG.Serializer` module is undefined.

- [ ] **Step 3: Implement `Plotto.SVG.Serializer`**

```elixir
defmodule Plotto.SVG.Serializer do
  @moduledoc false

  alias Plotto.SVG.Element

  def serialize(%Element{} = element) do
    render_element(element)
  end

  defp render_element(%Element{tag: tag, attrs: attrs, children: children}) do
    attrs_string = render_attrs(attrs)

    if children == [] do
      "<#{tag}#{attrs_string}/>"
    else
      children_string = Enum.map_join(children, "", &render_child/1)
      "<#{tag}#{attrs_string}>#{children_string}</#{tag}>"
    end
  end

  defp render_child(%Element{} = child), do: render_element(child)
  defp render_child(text) when is_binary(text), do: escape_text(text)

  defp render_attrs(attrs) do
    attrs
    |> Enum.sort()
    |> Enum.map_join("", fn {k, v} -> ~s( #{k}="#{escape_attr(v)}") end)
  end

  defp escape_attr(value) do
    value
    |> escape_text()
    |> String.replace("\"", "&quot;")
  end

  defp escape_text(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/svg/serializer_test.exs`
Expected: PASS (6 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/svg/serializer.ex test/plotto/svg/serializer_test.exs
git commit --no-gpg-sign -m "Add Plotto.SVG.Serializer with escaped XML output"
```

---

### Task 5: `Plotto.Data` and `Plotto.Options` — validation and option defaults

**Files:**
- Create: `lib/plotto/data.ex`
- Create: `lib/plotto/options.ex`
- Test: `test/plotto/data_test.exs`
- Test: `test/plotto/options_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.DataTest do
  use ExUnit.Case, async: true

  alias Plotto.Data

  test "valid data list passes validation" do
    assert Data.validate([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]) == :ok
  end

  test "valid item may include an :attrs map" do
    assert Data.validate([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}]) == :ok
  end

  test "rejects an empty list" do
    assert {:error, reason} = Data.validate([])
    assert reason =~ "empty"
  end

  test "rejects a non-list" do
    assert {:error, reason} = Data.validate(%{})
    assert reason =~ "list"
  end

  test "rejects an item missing :label" do
    assert {:error, _reason} = Data.validate([%{value: 10}])
  end

  test "rejects an item with a non-numeric :value" do
    assert {:error, _reason} = Data.validate([%{label: "Jan", value: "10"}])
  end

  test "rejects an item with a negative :value" do
    assert {:error, reason} = Data.validate([%{label: "Jan", value: -1}])
    assert reason =~ "negative"
  end
end
```

```elixir
defmodule Plotto.OptionsTest do
  use ExUnit.Case, async: true

  alias Plotto.Options

  test "fills in defaults when no opts given" do
    opts = Options.build([])
    assert opts.width == Plotto.Theme.default_width()
    assert opts.height == Plotto.Theme.default_height()
    assert opts.title == nil
    assert opts.colors == Plotto.Theme.default_colors()
  end

  test "overrides defaults with given opts" do
    opts = Options.build(width: 800, height: 500, title: "Sales", colors: ["#000000"])
    assert opts.width == 800
    assert opts.height == 500
    assert opts.title == "Sales"
    assert opts.colors == ["#000000"]
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/data_test.exs test/plotto/options_test.exs`
Expected: FAIL — `Plotto.Data` and `Plotto.Options` modules are undefined.

- [ ] **Step 3: Implement `Plotto.Data` and `Plotto.Options`**

```elixir
defmodule Plotto.Data do
  @moduledoc false

  def validate(data) when is_list(data) and data != [] do
    case Enum.find_value(data, &item_error/1) do
      nil -> :ok
      error -> {:error, error}
    end
  end

  def validate([]), do: {:error, "data must not be empty"}
  def validate(_data), do: {:error, "data must be a list"}

  defp item_error(%{label: label, value: value}) when is_binary(label) and is_number(value) do
    if value < 0 do
      "value must not be negative, got: #{inspect(value)} for label #{inspect(label)}"
    else
      nil
    end
  end

  defp item_error(item) do
    "invalid data item, expected a map with :label (string) and :value (number), got: #{inspect(item)}"
  end
end
```

```elixir
defmodule Plotto.Options do
  @moduledoc false

  alias Plotto.Theme

  def build(opts) do
    %{
      width: Keyword.get(opts, :width, Theme.default_width()),
      height: Keyword.get(opts, :height, Theme.default_height()),
      title: Keyword.get(opts, :title),
      colors: Keyword.get(opts, :colors, Theme.default_colors())
    }
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/data_test.exs test/plotto/options_test.exs`
Expected: PASS (9 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/data.ex lib/plotto/options.ex test/plotto/data_test.exs test/plotto/options_test.exs
git commit --no-gpg-sign -m "Add Plotto.Data validation and Plotto.Options defaults"
```

---

### Task 6: `Plotto.Chart.Builder`, `Plotto.BarChart`, `Plotto.LineChart`

**Files:**
- Create: `lib/plotto/chart/builder.ex`
- Create: `lib/plotto/bar_chart.ex`
- Create: `lib/plotto/line_chart.ex`
- Test: `test/plotto/bar_chart_test.exs`
- Test: `test/plotto/line_chart_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart

  @valid_data [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]

  test "new/2 returns {:ok, chart} for valid data" do
    assert {:ok, %BarChart{data: @valid_data}} = BarChart.new(@valid_data)
  end

  test "new/2 applies default opts when none given" do
    {:ok, chart} = BarChart.new(@valid_data)
    assert chart.opts.width == Plotto.Theme.default_width()
  end

  test "new/2 returns {:error, reason} for invalid data" do
    assert {:error, _reason} = BarChart.new([])
  end

  test "new!/2 returns the chart struct for valid data" do
    assert %BarChart{} = BarChart.new!(@valid_data, title: "Sales")
  end

  test "new!/2 raises ArgumentError for invalid data" do
    assert_raise ArgumentError, fn -> BarChart.new!([]) end
  end
end
```

```elixir
defmodule Plotto.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart

  @valid_data [%{label: "Jan", value: 10}, %{label: "Feb", value: 25}]

  test "new/2 returns {:ok, chart} for valid data" do
    assert {:ok, %LineChart{data: @valid_data}} = LineChart.new(@valid_data)
  end

  test "new/2 returns {:error, reason} for invalid data" do
    assert {:error, _reason} = LineChart.new([])
  end

  test "new!/2 returns the chart struct for valid data" do
    assert %LineChart{} = LineChart.new!(@valid_data, title: "Trend")
  end

  test "new!/2 raises ArgumentError for invalid data" do
    assert_raise ArgumentError, fn -> LineChart.new!([]) end
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs`
Expected: FAIL — `Plotto.BarChart` and `Plotto.LineChart` modules are undefined.

- [ ] **Step 3: Implement `Plotto.Chart.Builder`, `Plotto.BarChart`, `Plotto.LineChart`**

```elixir
defmodule Plotto.Chart.Builder do
  @moduledoc false

  alias Plotto.{Data, Options}

  def new(module, data, opts) do
    case Data.validate(data) do
      :ok -> {:ok, struct(module, data: data, opts: Options.build(opts))}
      {:error, _reason} = error -> error
    end
  end

  def new!(module, data, opts) do
    case new(module, data, opts) do
      {:ok, chart} -> chart
      {:error, reason} -> raise ArgumentError, reason
    end
  end
end
```

```elixir
defmodule Plotto.BarChart do
  @moduledoc """
  A bar chart: one bar per data item, bar height proportional to `:value`.
  """

  defstruct [:data, :opts]

  @type t :: %__MODULE__{data: [map()], opts: map()}

  @doc """
  Builds a bar chart. Returns `{:ok, chart}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, chart} = Plotto.BarChart.new([%{label: "Jan", value: 10}])
      iex> chart.data
      [%{label: "Jan", value: 10}]

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc "Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an error tuple."
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
```

```elixir
defmodule Plotto.LineChart do
  @moduledoc """
  A line chart: a single line connecting one point per data item.
  """

  defstruct [:data, :opts]

  @type t :: %__MODULE__{data: [map()], opts: map()}

  @doc """
  Builds a line chart. Returns `{:ok, chart}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, chart} = Plotto.LineChart.new([%{label: "Jan", value: 10}])
      iex> chart.data
      [%{label: "Jan", value: 10}]

  """
  def new(data, opts \\ []), do: Plotto.Chart.Builder.new(__MODULE__, data, opts)

  @doc "Same as `new/2`, but raises `ArgumentError` on invalid data instead of returning an error tuple."
  def new!(data, opts \\ []), do: Plotto.Chart.Builder.new!(__MODULE__, data, opts)
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs`
Expected: PASS (9 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/chart lib/plotto/bar_chart.ex lib/plotto/line_chart.ex test/plotto/bar_chart_test.exs test/plotto/line_chart_test.exs
git commit --no-gpg-sign -m "Add Plotto.BarChart and Plotto.LineChart structs via shared Chart.Builder"
```

---

### Task 7: `Plotto.SVG.Renderer.Shared` — axis, title and root builders

**Files:**
- Create: `lib/plotto/svg/renderer/shared.ex`
- Test: `test/plotto/svg/renderer/shared_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.SVG.Renderer.SharedTest do
  use ExUnit.Case, async: true

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared

  test "svg_root/3 builds a root <svg> element with viewBox and given children" do
    child = Element.new("rect")
    root = Shared.svg_root(600, 400, [child])

    assert root.tag == "svg"
    assert root.attrs["viewBox"] == "0 0 600 400"
    assert root.attrs["width"] == "600"
    assert root.attrs["height"] == "400"
    assert root.children == [child]
  end

  test "title_elements/2 returns [] when title is nil" do
    assert Shared.title_elements(nil, 600) == []
  end

  test "title_elements/2 returns a centered <text> element when title is given" do
    [title] = Shared.title_elements("Sales", 600)
    assert title.tag == "text"
    assert title.attrs["text-anchor"] == "middle"
    assert title.children == ["Sales"]
  end

  test "axis_elements/5 returns one axis line pair plus one text label per band and per tick" do
    bands = Plotto.Axis.categorical_scale(["Jan", "Feb"], 200)
    margin = Plotto.Theme.margin()

    elements = Shared.axis_elements(bands, margin, 200, 100, 10)

    lines = Enum.filter(elements, &(&1.tag == "line"))
    texts = Enum.filter(elements, &(&1.tag == "text"))

    assert length(lines) == 2
    # 2 x-axis labels (Jan, Feb) + 6 y-axis tick labels (0, 2, 4, 6, 8, 10)
    assert length(texts) == 8
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/shared_test.exs`
Expected: FAIL — `Plotto.SVG.Renderer.Shared` module is undefined.

- [ ] **Step 3: Implement `Plotto.SVG.Renderer.Shared`**

```elixir
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/shared_test.exs`
Expected: PASS (4 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer/shared.ex test/plotto/svg/renderer/shared_test.exs
git commit --no-gpg-sign -m "Add Plotto.SVG.Renderer.Shared axis/title/root builders"
```

---

### Task 8: `Plotto.SVG.Renderer.BarChart`

**Files:**
- Create: `lib/plotto/svg/renderer/bar_chart.ex`
- Test: `test/plotto/svg/renderer/bar_chart_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.SVG.Renderer.BarChartTest do
  use ExUnit.Case, async: true

  alias Plotto.BarChart
  alias Plotto.SVG.Renderer.BarChart, as: Renderer

  test "render/1 returns an <svg> root with one <rect> per data item" do
    chart = BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))
    assert length(rects) == 2
  end

  test "each bar gets a fill color from the theme palette" do
    chart = BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)
    rects = Enum.filter(svg.children, &(&1.tag == "rect"))

    assert Enum.all?(rects, &String.starts_with?(&1.attrs["fill"], "#"))
  end

  test "per-item :attrs are merged onto the corresponding <rect>" do
    chart =
      BarChart.new!([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}])

    svg = Renderer.render(chart)
    [rect] = Enum.filter(svg.children, &(&1.tag == "rect"))

    assert rect.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = BarChart.new!([%{label: "Jan", value: 10}], title: "Sales")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Sales"]} -> true
             _ -> false
           end)
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/bar_chart_test.exs`
Expected: FAIL — `Plotto.SVG.Renderer.BarChart` module is undefined.

- [ ] **Step 3: Implement `Plotto.SVG.Renderer.BarChart`**

```elixir
defmodule Plotto.SVG.Renderer.BarChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.BarChart{data: data, opts: opts}) do
    margin = Theme.margin()
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = Enum.map(data, & &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = data |> Enum.map(& &1.value) |> Enum.max()

    bars =
      data
      |> Enum.zip(bands)
      |> Enum.with_index()
      |> Enum.map(&build_bar(&1, margin, plot_height, max_value, opts.colors))

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        bars ++ Shared.title_elements(opts.title, opts.width)

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp build_bar({{item, band}, index}, margin, plot_height, max_value, colors) do
    bar_width = band.band_width * 0.8
    bar_x = margin.left + band.band_x + band.band_width * 0.1
    top_y = margin.top + Axis.linear_scale(item.value, max_value, plot_height)
    bar_height = plot_height - Axis.linear_scale(item.value, max_value, plot_height)

    attrs =
      %{
        "x" => bar_x,
        "y" => top_y,
        "width" => bar_width,
        "height" => bar_height,
        "fill" => Theme.color(colors, index)
      }
      |> Map.merge(Map.get(item, :attrs, %{}))

    Element.new("rect", attrs)
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/bar_chart_test.exs`
Expected: PASS (4 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer/bar_chart.ex test/plotto/svg/renderer/bar_chart_test.exs
git commit --no-gpg-sign -m "Add Plotto.SVG.Renderer.BarChart"
```

---

### Task 9: `Plotto.SVG.Renderer.LineChart`

**Files:**
- Create: `lib/plotto/svg/renderer/line_chart.ex`
- Test: `test/plotto/svg/renderer/line_chart_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.SVG.Renderer.LineChartTest do
  use ExUnit.Case, async: true

  alias Plotto.LineChart
  alias Plotto.SVG.Renderer.LineChart, as: Renderer

  test "render/1 returns an <svg> root with a single <polyline>" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)

    assert svg.tag == "svg"
    polylines = Enum.filter(svg.children, &(&1.tag == "polyline"))
    assert length(polylines) == 1
  end

  test "the polyline has one x,y coordinate pair per data item" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)
    [polyline] = Enum.filter(svg.children, &(&1.tag == "polyline"))

    points = String.split(polyline.attrs["points"], " ")
    assert length(points) == 2
  end

  test "renders one <circle> per data item" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Renderer.render(chart)
    circles = Enum.filter(svg.children, &(&1.tag == "circle"))
    assert length(circles) == 2
  end

  test "per-item :attrs are merged onto the corresponding <circle>" do
    chart =
      LineChart.new!([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}])

    svg = Renderer.render(chart)
    [circle] = Enum.filter(svg.children, &(&1.tag == "circle"))

    assert circle.attrs["phx-click"] == "select"
  end

  test "includes a title text element when opts.title is set" do
    chart = LineChart.new!([%{label: "Jan", value: 10}], title: "Trend")
    svg = Renderer.render(chart)

    assert Enum.any?(svg.children, fn
             %{tag: "text", children: ["Trend"]} -> true
             _ -> false
           end)
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/svg/renderer/line_chart_test.exs`
Expected: FAIL — `Plotto.SVG.Renderer.LineChart` module is undefined.

- [ ] **Step 3: Implement `Plotto.SVG.Renderer.LineChart`**

```elixir
defmodule Plotto.SVG.Renderer.LineChart do
  @moduledoc false

  alias Plotto.SVG.Element
  alias Plotto.SVG.Renderer.Shared
  alias Plotto.{Axis, Theme}

  def render(%Plotto.LineChart{data: data, opts: opts}) do
    margin = Theme.margin()
    plot_width = opts.width - margin.left - margin.right
    plot_height = opts.height - margin.top - margin.bottom

    labels = Enum.map(data, & &1.label)
    bands = Axis.categorical_scale(labels, plot_width)
    max_value = data |> Enum.map(& &1.value) |> Enum.max()
    color = List.first(opts.colors)

    points =
      data
      |> Enum.zip(bands)
      |> Enum.map(fn {item, band} ->
        x = margin.left + band.x
        y = margin.top + Axis.linear_scale(item.value, max_value, plot_height)
        {item, x, y}
      end)

    children =
      Shared.axis_elements(bands, margin, plot_width, plot_height, max_value) ++
        [build_polyline(points, color)] ++
        Enum.map(points, &build_point_circle(&1, color)) ++
        Shared.title_elements(opts.title, opts.width)

    Shared.svg_root(opts.width, opts.height, children)
  end

  defp build_polyline(points, color) do
    points_attr = Enum.map_join(points, " ", fn {_item, x, y} -> "#{fmt(x)},#{fmt(y)}" end)

    Element.new("polyline", %{
      "points" => points_attr,
      "fill" => "none",
      "stroke" => color
    })
  end

  defp fmt(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp fmt(v), do: to_string(v)

  defp build_point_circle({item, x, y}, color) do
    attrs =
      %{"cx" => x, "cy" => y, "r" => 3, "fill" => color}
      |> Map.merge(Map.get(item, :attrs, %{}))

    Element.new("circle", attrs)
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/svg/renderer/line_chart_test.exs`
Expected: PASS (5 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer/line_chart.ex test/plotto/svg/renderer/line_chart_test.exs
git commit --no-gpg-sign -m "Add Plotto.SVG.Renderer.LineChart"
```

---

### Task 10: `Plotto.SVG.Renderer` dispatcher

**Files:**
- Create: `lib/plotto/svg/renderer.ex`
- Test: `test/plotto/svg/renderer_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Plotto.SVG.RendererTest do
  use ExUnit.Case, async: true

  alias Plotto.{BarChart, LineChart}
  alias Plotto.SVG.Renderer

  test "dispatches BarChart to the bar chart renderer" do
    chart = BarChart.new!([%{label: "Jan", value: 10}])
    svg = Renderer.render(chart)
    assert svg.tag == "svg"
    assert Enum.any?(svg.children, &(&1.tag == "rect"))
  end

  test "dispatches LineChart to the line chart renderer" do
    chart = LineChart.new!([%{label: "Jan", value: 10}])
    svg = Renderer.render(chart)
    assert svg.tag == "svg"
    assert Enum.any?(svg.children, &(&1.tag == "polyline"))
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto/svg/renderer_test.exs`
Expected: FAIL — `Plotto.SVG.Renderer` module is undefined.

- [ ] **Step 3: Implement `Plotto.SVG.Renderer`**

```elixir
defmodule Plotto.SVG.Renderer do
  @moduledoc false

  def render(%Plotto.BarChart{} = chart), do: Plotto.SVG.Renderer.BarChart.render(chart)
  def render(%Plotto.LineChart{} = chart), do: Plotto.SVG.Renderer.LineChart.render(chart)
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test test/plotto/svg/renderer_test.exs`
Expected: PASS (2 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto/svg/renderer.ex test/plotto/svg/renderer_test.exs
git commit --no-gpg-sign -m "Add Plotto.SVG.Renderer dispatcher"
```

---

### Task 11: `Plotto` public API — `to_svg/1` and `to_svg!/1`

**Files:**
- Modify: `lib/plotto.ex` (replace the `mix new` boilerplate entirely)
- Modify: `test/plotto_test.exs` (replace the `mix new` boilerplate entirely)

- [ ] **Step 1: Write the failing tests**

Replace the full contents of `test/plotto_test.exs` with:

```elixir
defmodule PlottoTest do
  use ExUnit.Case, async: true

  doctest Plotto.BarChart
  doctest Plotto.LineChart

  alias Plotto.{BarChart, LineChart}

  test "to_svg/1 returns {:ok, svg_string} for a bar chart" do
    chart = BarChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    assert {:ok, svg} = Plotto.to_svg(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<rect"
  end

  test "to_svg!/1 returns the svg string directly for a line chart" do
    chart = LineChart.new!([%{label: "Jan", value: 10}, %{label: "Feb", value: 25}])
    svg = Plotto.to_svg!(chart)
    assert String.starts_with?(svg, "<svg")
    assert svg =~ "<polyline"
  end

  test "per-item attrs pass through end to end into the SVG output" do
    chart =
      BarChart.new!([%{label: "Jan", value: 10, attrs: %{"phx-click" => "select"}}])

    svg = Plotto.to_svg!(chart)
    assert svg =~ ~s(phx-click="select")
  end

  test "labels with special characters are escaped end to end" do
    chart = BarChart.new!([%{label: "<script>", value: 10}])
    svg = Plotto.to_svg!(chart)
    refute svg =~ "<script>"
    assert svg =~ "&lt;script&gt;"
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mix test test/plotto_test.exs`
Expected: FAIL — `Plotto.to_svg/1` is undefined (current `lib/plotto.ex` only defines `hello/0`).

- [ ] **Step 3: Implement `Plotto`**

Replace the full contents of `lib/plotto.ex` with:

```elixir
defmodule Plotto do
  @moduledoc """
  Plotto generates SVG charts in pure Elixir.

  ## Example

      chart = Plotto.BarChart.new!([%{label: "Jan", value: 10}], title: "Sales")
      svg = Plotto.to_svg!(chart)

  """

  alias Plotto.SVG.{Renderer, Serializer}

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
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mix test`
Expected: PASS (entire suite, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add lib/plotto.ex test/plotto_test.exs
git commit --no-gpg-sign -m "Add Plotto.to_svg/1 and to_svg!/1 public API"
```

---

## Definition of done

- `mix test` passes with 0 failures.
- `mix format --check-formatted` passes (run `mix format` first if not).
- `Plotto.BarChart.new!(data, opts) |> Plotto.to_svg!/1` and the equivalent for `Plotto.LineChart` produce a valid-looking SVG string containing axis lines, labels, a title (when given), and per-item passthrough attributes.
- No new dependencies were added to `mix.exs`.
