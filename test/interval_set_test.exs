defmodule Tempo.Ecto.IntervalSetTest do
  use ExUnit.Case, async: true

  alias Tempo.Ecto.IntervalSet

  defp interval(from_str, to_str) do
    from = Tempo.from_iso8601!(from_str)
    to = Tempo.from_iso8601!(to_str)
    {:ok, iv} = Tempo.Interval.new(from: from, to: to)
    iv
  end

  describe "type/0" do
    test "reports tstzmultirange" do
      assert IntervalSet.type() == :tstzmultirange
    end
  end

  describe "dump/1" do
    test "dumps a set of anchored intervals as a Postgrex.Multirange" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval("2026-06-15T14:00:00", "2026-06-15T15:00:00")
      {:ok, set} = Tempo.IntervalSet.new([a, b])

      assert {:ok, %Postgrex.Multirange{ranges: ranges}} = IntervalSet.dump(set)
      assert length(ranges) == 2
      assert Enum.all?(ranges, fn r -> match?(%Postgrex.Range{}, r) end)
    end

    test "refuses an empty set" do
      empty = %Tempo.IntervalSet{intervals: []}
      assert :error = IntervalSet.dump(empty)
    end

    test "refuses a set whose member violates the Interval contract" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      recurring = %{a | recurrence: 3}
      set = %Tempo.IntervalSet{intervals: [recurring]}

      assert :error = IntervalSet.dump(set)
    end
  end

  describe "load/1" do
    test "loads a Postgrex.Multirange into an IntervalSet" do
      multirange = %Postgrex.Multirange{
        ranges: [
          %Postgrex.Range{
            lower: ~U[2026-06-15 09:00:00Z],
            upper: ~U[2026-06-15 10:00:00Z]
          },
          %Postgrex.Range{
            lower: ~U[2026-06-15 14:00:00Z],
            upper: ~U[2026-06-15 15:00:00Z]
          }
        ]
      }

      assert {:ok, %Tempo.IntervalSet{intervals: intervals}} = IntervalSet.load(multirange)
      assert length(intervals) == 2
    end
  end

  describe "cast/1" do
    test "accepts a list of intervals and wraps in an IntervalSet" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval("2026-06-15T14:00:00", "2026-06-15T15:00:00")

      assert {:ok, %Tempo.IntervalSet{}} = IntervalSet.cast([a, b])
    end

    test "accepts an IntervalSet unchanged" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      {:ok, set} = Tempo.IntervalSet.new([a])

      assert {:ok, ^set} = IntervalSet.cast(set)
    end
  end

  describe "round-trip" do
    test "set dumps and loads back with the same member count and endpoints" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval("2026-06-15T14:00:00", "2026-06-15T15:00:00")
      {:ok, original} = Tempo.IntervalSet.new([a, b])

      {:ok, multirange} = IntervalSet.dump(original)
      {:ok, loaded} = IntervalSet.load(multirange)

      assert length(loaded.intervals) == 2
    end
  end
end
