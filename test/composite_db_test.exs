defmodule Tempo.SQL.CompositeDBTest do
  use Tempo.SQL.Test.RepoCase

  import Tempo.Ecto.QueryAPI.Composite

  describe "Tempo.Ecto.TempoRange end-to-end" do
    test "inserts and reads back a second-resolution interval" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T10:00:00")
      {:ok, window} = Tempo.Interval.new(from: from, to: to)

      row = Repo.insert!(%FidelityMeeting{name: "Standup", window: window})
      fetched = Repo.get!(FidelityMeeting, row.id)

      assert %Tempo.Interval{} = fetched.window
      assert Keyword.get(fetched.window.from.time, :hour) == 9
      assert Keyword.get(fetched.window.to.time, :hour) == 10
    end

    test "round-trips an interval's endpoints at the shape they went in with" do
      # This is the headline feature — whatever Tempo endpoints you
      # hand the composite, you get back byte-for-byte via the meta
      # column. The plain-range Tempo.Ecto.Tempo type materialises
      # everything to second resolution; the composite preserves it.
      {:ok, original} = Tempo.from_iso8601!("2026-06") |> Tempo.to_interval()

      row = Repo.insert!(%FidelityMeeting{name: "June", window: original})
      fetched = Repo.get!(FidelityMeeting, row.id)

      assert fetched.window.from.time == original.from.time
      assert fetched.window.to.time == original.to.time
    end

    test "round-trips qualifications" do
      {:ok, interval} = Tempo.from_iso8601("1984?/2004~")

      row = Repo.insert!(%FidelityMeeting{name: "Uncertain history", window: interval})
      fetched = Repo.get!(FidelityMeeting, row.id)

      assert fetched.window.from.qualification == :uncertain
      assert fetched.window.to.qualification == :approximate
    end

    test "round-trips a recurrence rule" do
      {:ok, interval} = Tempo.from_iso8601("R5/2022-01-01/P1M")

      row = Repo.insert!(%FidelityMeeting{name: "Five-month series", window: interval})
      fetched = Repo.get!(FidelityMeeting, row.id)

      assert fetched.window.recurrence == 5
      assert %Tempo.Duration{} = fetched.window.duration
    end

    test "queries with composite `contains` — the range column stays queryable" do
      a = interval_between("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval_between("2026-06-15T14:00:00", "2026-06-15T15:00:00")

      Repo.insert!(%FidelityMeeting{name: "Morning", window: a})
      Repo.insert!(%FidelityMeeting{name: "Afternoon", window: b})

      instant_at_930 = %Postgrex.Range{
        lower: ~U[2026-06-15 09:30:00Z],
        upper: ~U[2026-06-15 09:30:00Z],
        lower_inclusive: true,
        upper_inclusive: true
      }

      names =
        Repo.all(
          from m in FidelityMeeting,
            where: contains(m.window, ^instant_at_930),
            select: m.name
        )

      assert names == ["Morning"]
    end
  end

  describe "Tempo.Ecto.TempoMultirange end-to-end" do
    test "round-trips a set of anchored intervals" do
      a = interval_between("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval_between("2026-06-15T14:00:00", "2026-06-15T15:00:00")
      {:ok, busy} = Tempo.IntervalSet.new([a, b])

      row = Repo.insert!(%FidelityCalendar{owner: "alice", busy_times: busy})
      fetched = Repo.get!(FidelityCalendar, row.id)

      assert length(fetched.busy_times.intervals) == 2
      assert Enum.at(fetched.busy_times.intervals, 0).from.time |> Keyword.get(:hour) == 9
      assert Enum.at(fetched.busy_times.intervals, 1).from.time |> Keyword.get(:hour) == 14
    end

    test "round-trips a set whose members have qualifications" do
      {:ok, uncertain_a} = Tempo.from_iso8601("1984?/1985")
      {:ok, uncertain_b} = Tempo.from_iso8601("1990/1991~")
      {:ok, set} = Tempo.IntervalSet.new([uncertain_a, uncertain_b])

      row = Repo.insert!(%FidelityCalendar{owner: "archivist", busy_times: set})
      fetched = Repo.get!(FidelityCalendar, row.id)

      [a, b] = fetched.busy_times.intervals
      assert a.from.qualification == :uncertain
      assert b.to.qualification == :approximate
    end
  end

  defp interval_between(from_str, to_str) do
    from = Tempo.from_iso8601!(from_str)
    to = Tempo.from_iso8601!(to_str)
    {:ok, iv} = Tempo.Interval.new(from: from, to: to)
    iv
  end
end
