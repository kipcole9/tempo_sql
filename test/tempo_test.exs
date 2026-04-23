defmodule Tempo.Ecto.TempoTest do
  use ExUnit.Case, async: true

  alias Tempo.Ecto.Tempo, as: EctoTempo

  describe "type/0" do
    test "reports tstzrange" do
      assert EctoTempo.type() == :tstzrange
    end
  end

  describe "dump/1 — implicit-span materialisation" do
    test "materialises a year-only Tempo to its annual span" do
      {:ok, year} = {:ok, Tempo.from_iso8601!("2026")}

      assert {:ok, %Postgrex.Range{} = range} = EctoTempo.dump(year)
      assert range.lower == ~U[2026-01-01 00:00:00Z]
      assert range.upper == ~U[2027-01-01 00:00:00Z]
    end

    test "materialises a year-month Tempo to its monthly span" do
      {:ok, month} = {:ok, Tempo.from_iso8601!("2026-06")}

      assert {:ok, %Postgrex.Range{} = range} = EctoTempo.dump(month)
      assert range.lower == ~U[2026-06-01 00:00:00Z]
      assert range.upper == ~U[2026-07-01 00:00:00Z]
    end

    test "materialises a day-resolution Tempo to a 24-hour span" do
      {:ok, day} = {:ok, Tempo.from_iso8601!("2026-06-15")}

      assert {:ok, %Postgrex.Range{} = range} = EctoTempo.dump(day)
      assert range.lower == ~U[2026-06-15 00:00:00Z]
      assert range.upper == ~U[2026-06-16 00:00:00Z]
    end

    test "passes through a fully-anchored Interval" do
      {:ok, from} = {:ok, Tempo.from_iso8601!("2026-06-15T09:00:00")}
      {:ok, to} = {:ok, Tempo.from_iso8601!("2026-06-15T17:00:00")}
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)

      assert {:ok, %Postgrex.Range{}} = EctoTempo.dump(interval)
    end
  end

  describe "cast/1" do
    test "materialises an implicit span" do
      {:ok, tempo} = {:ok, Tempo.from_iso8601!("2026-06")}
      assert {:ok, %Tempo.Interval{}} = EctoTempo.cast(tempo)
    end

    test "accepts a Postgrex.Range" do
      range = %Postgrex.Range{lower: ~U[2026-01-01 00:00:00Z], upper: ~U[2027-01-01 00:00:00Z]}
      assert {:ok, %Tempo.Interval{}} = EctoTempo.cast(range)
    end
  end
end
