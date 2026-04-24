defmodule Tempo.Ecto.TempoTest do
  use ExUnit.Case, async: true

  alias Tempo.Ecto.Tempo, as: EctoTempo

  @default_params %{resolution: :second}

  describe "type/1" do
    test "reports tstzrange" do
      assert EctoTempo.type(@default_params) == :tstzrange
    end
  end

  describe "dump/3 — implicit-span materialisation" do
    test "materialises a year-only Tempo to its annual span" do
      year = Tempo.from_iso8601!("2026")

      assert {:ok, %Postgrex.Range{} = range} = EctoTempo.dump(year, nil, @default_params)
      assert range.lower == ~U[2026-01-01 00:00:00Z]
      assert range.upper == ~U[2027-01-01 00:00:00Z]
    end

    test "materialises a year-month Tempo to its monthly span" do
      month = Tempo.from_iso8601!("2026-06")

      assert {:ok, %Postgrex.Range{} = range} = EctoTempo.dump(month, nil, @default_params)
      assert range.lower == ~U[2026-06-01 00:00:00Z]
      assert range.upper == ~U[2026-07-01 00:00:00Z]
    end

    test "materialises a day-resolution Tempo to a 24-hour span" do
      day = Tempo.from_iso8601!("2026-06-15")

      assert {:ok, %Postgrex.Range{} = range} = EctoTempo.dump(day, nil, @default_params)
      assert range.lower == ~U[2026-06-15 00:00:00Z]
      assert range.upper == ~U[2026-06-16 00:00:00Z]
    end

    test "passes through a fully-anchored Interval" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)

      assert {:ok, %Postgrex.Range{}} = EctoTempo.dump(interval, nil, @default_params)
    end
  end

  describe "load/3 — :resolution recovers implicit-span shape" do
    test "resolution: :year on a one-year range loads as a year-resolution interval" do
      params = EctoTempo.init(resolution: :year)

      year = Tempo.from_iso8601!("2026")
      {:ok, range} = EctoTempo.dump(year, nil, params)
      {:ok, interval} = EctoTempo.load(range, nil, params)

      # Closest thing to a round-trip of `~o"2026Y"` that tstzrange allows.
      assert interval.from.time == [year: 2026]
      assert interval.to.time == [year: 2027]
    end
  end

  describe "cast/2" do
    test "materialises an implicit span" do
      tempo = Tempo.from_iso8601!("2026-06")
      assert {:ok, %Tempo.Interval{}} = EctoTempo.cast(tempo, @default_params)
    end

    test "accepts a Postgrex.Range" do
      range = %Postgrex.Range{lower: ~U[2026-01-01 00:00:00Z], upper: ~U[2027-01-01 00:00:00Z]}
      assert {:ok, %Tempo.Interval{}} = EctoTempo.cast(range, @default_params)
    end
  end
end
