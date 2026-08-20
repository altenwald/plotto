defmodule Plotto.CandlestickDataTest do
  use ExUnit.Case, async: true

  alias Plotto.CandlestickData

  @valid_flat [
    %{label: "09:00", open: 100, high: 105, low: 95, close: 102},
    %{label: "09:05", open: 102, high: 108, low: 101, close: 107}
  ]

  @valid_series [
    %{
      name: "AAPL",
      data: [
        %{label: "09:00", open: 100, high: 105, low: 95, close: 102},
        %{label: "09:05", open: 102, high: 108, low: 101, close: 107}
      ]
    }
  ]

  test "a valid flat OHLC list passes validation" do
    assert CandlestickData.validate(@valid_flat) == :ok
  end

  test "a valid series-wrapped OHLC list passes validation" do
    assert CandlestickData.validate(@valid_series) == :ok
  end

  test "a valid item may include an :attrs map" do
    data = [
      %{label: "09:00", open: 100, high: 105, low: 95, close: 102, attrs: %{"phx-click" => "select"}}
    ]

    assert CandlestickData.validate(data) == :ok
  end

  test "rejects an empty list" do
    assert {:error, reason} = CandlestickData.validate([])
    assert reason =~ "empty"
  end

  test "rejects a non-list" do
    assert {:error, reason} = CandlestickData.validate(%{})
    assert reason =~ "list"
  end

  test "rejects an item missing required OHLC keys" do
    data = [%{label: "09:00", open: 100, high: 105, low: 95}]
    assert {:error, reason} = CandlestickData.validate(data)
    assert reason =~ "missing" or reason =~ "invalid"
  end

  test "rejects an item with non-numeric price" do
    data = [%{label: "09:00", open: "100", high: 105, low: 95, close: 102}]
    assert {:error, _reason} = CandlestickData.validate(data)
  end

  test "rejects an item where high is lower than open or close" do
    data = [%{label: "09:00", open: 100, high: 98, low: 90, close: 95}]
    assert {:error, reason} = CandlestickData.validate(data)
    assert reason =~ "high"
  end

  test "rejects an item where low is higher than open or close" do
    data = [%{label: "09:00", open: 100, high: 110, low: 105, close: 108}]
    assert {:error, reason} = CandlestickData.validate(data)
    assert reason =~ "low"
  end

  describe "normalize/1" do
    test "wraps a flat OHLC list into a single series with name nil" do
      assert CandlestickData.normalize(@valid_flat) == [%{name: nil, data: @valid_flat}]
    end

    test "leaves an already-wrapped series list intact" do
      assert CandlestickData.normalize(@valid_series) == @valid_series
    end
  end
end
