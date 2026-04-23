defmodule Tempo.Ecto.IntervalTest do
  use ExUnit.Case, async: true

  alias Tempo.Ecto.Interval

  describe "type/0" do
    test "reports tstzrange" do
      assert Interval.type() == :tstzrange
    end
  end

  describe "dump/1 — the storable shape" do
    test "dumps a fully-anchored %Tempo.Interval{} as a Postgrex.Range in UTC" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)

      assert {:ok, %Postgrex.Range{} = range} = Interval.dump(interval)
      assert %DateTime{year: 2026, month: 6, day: 15, hour: 9} = range.lower
      assert %DateTime{year: 2026, month: 6, day: 15, hour: 17} = range.upper
      assert range.lower_inclusive == true
      assert range.upper_inclusive == false
    end

    test "dumps an open-start interval as a Range with :unbound lower" do
      {:ok, to} = {:ok, Tempo.from_iso8601!("2026-06-15T17:00:00")}
      {:ok, interval} = Tempo.Interval.new(from: :undefined, to: to)

      assert {:ok, %Postgrex.Range{lower: :unbound}} = Interval.dump(interval)
    end

    test "dumps an open-end interval as a Range with :unbound upper" do
      {:ok, from} = {:ok, Tempo.from_iso8601!("2026-06-15T09:00:00")}
      {:ok, interval} = Tempo.Interval.new(from: from, to: :undefined)

      assert {:ok, %Postgrex.Range{upper: :unbound}} = Interval.dump(interval)
    end

    test "returns nil passthrough" do
      assert {:ok, nil} = Interval.dump(nil)
    end
  end

  describe "dump/1 — the contract refusal cases" do
    test "refuses an interval with a recurrence count" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)
      recurring = %{interval | recurrence: 5}

      assert :error = Interval.dump(recurring)
    end

    test "refuses an interval with a repeat rule" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)
      rule = %Tempo{time: [year: 2026]}

      assert :error = Interval.dump(%{interval | repeat_rule: rule})
    end

    test "refuses a fully-unbounded interval" do
      {:ok, interval} = Tempo.Interval.new(from: :undefined, to: :undefined, duration: nil)
      # IntervalSet.new rejects this but the constructor may allow it
      # as a raw Interval — we enforce the refusal at the storage layer.
      assert :error = Interval.dump(interval)
    end

    test "accepts a year-only Tempo endpoint — fills in calendar defaults" do
      # Per the storage contract, partial endpoints are legal and
      # represent the start of their span (half-open `[from, to)`).
      # This is how implicit-span materialisation works.
      partial = %Tempo{time: [year: 2026]}
      {:ok, to} = {:ok, Tempo.from_iso8601!("2027-01-01T00:00:00")}
      {:ok, interval} = Tempo.Interval.new(from: partial, to: to)

      assert {:ok, %Postgrex.Range{lower: ~U[2026-01-01 00:00:00Z]}} = Interval.dump(interval)
    end

    test "refuses an ordinal-date Tempo endpoint (must be materialised first)" do
      # An ordinal date like `2026-075` (year + day-of-year) has no
      # month — we reject rather than guess at calendar conversion.
      ordinal = %Tempo{time: [year: 2026, day: 75]}
      {:ok, to} = {:ok, Tempo.from_iso8601!("2027-01-01T00:00:00")}
      {:ok, interval} = Tempo.Interval.new(from: ordinal, to: to)

      assert :error = Interval.dump(interval)
    end

    test "refuses a non-%Tempo.Interval{} value" do
      assert :error = Interval.dump("not a range")
      assert :error = Interval.dump(42)
    end
  end

  describe "load/1" do
    test "loads a Postgrex.Range back into a %Tempo.Interval{}" do
      range = %Postgrex.Range{
        lower: ~U[2026-06-15 09:00:00Z],
        upper: ~U[2026-06-15 17:00:00Z],
        lower_inclusive: true,
        upper_inclusive: false
      }

      assert {:ok, %Tempo.Interval{from: %Tempo{}, to: %Tempo{}} = interval} = Interval.load(range)
      assert Keyword.get(interval.from.time, :year) == 2026
      assert Keyword.get(interval.from.time, :hour) == 9
      assert Keyword.get(interval.to.time, :hour) == 17
    end

    test "loads an unbound lower as :undefined" do
      range = %Postgrex.Range{
        lower: :unbound,
        upper: ~U[2026-06-15 17:00:00Z]
      }

      assert {:ok, %Tempo.Interval{from: :undefined}} = Interval.load(range)
    end

    test "returns nil passthrough" do
      assert {:ok, nil} = Interval.load(nil)
    end
  end

  describe "cast/1 — the input-accepting surface" do
    test "accepts a %Tempo.Interval{} unchanged" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)

      assert {:ok, ^interval} = Interval.cast(interval)
    end

    test "materialises a bare %Tempo{} via Tempo.to_interval/1" do
      {:ok, tempo} = {:ok, Tempo.from_iso8601!("2026-06-15")}

      assert {:ok, %Tempo.Interval{from: %Tempo{}, to: %Tempo{}}} = Interval.cast(tempo)
    end

    test "accepts a Postgrex.Range" do
      range = %Postgrex.Range{
        lower: ~U[2026-06-15 09:00:00Z],
        upper: ~U[2026-06-15 17:00:00Z]
      }

      assert {:ok, %Tempo.Interval{}} = Interval.cast(range)
    end

    test "rejects unknown input" do
      assert :error = Interval.cast("2026")
      assert :error = Interval.cast(%{random: "map"})
    end
  end

  describe "round-trip" do
    test "an anchored interval dumps and loads back with the same endpoints" do
      {:ok, from} = {:ok, Tempo.from_iso8601!("2026-06-15T09:00:00")}
      {:ok, to} = {:ok, Tempo.from_iso8601!("2026-06-15T17:00:00")}
      {:ok, original} = Tempo.Interval.new(from: from, to: to)

      {:ok, range} = Interval.dump(original)
      {:ok, loaded} = Interval.load(range)

      assert Keyword.get(loaded.from.time, :year) == 2026
      assert Keyword.get(loaded.from.time, :hour) == 9
      assert Keyword.get(loaded.to.time, :hour) == 17
    end
  end
end
