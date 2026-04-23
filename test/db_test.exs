defmodule Tempo.SQL.DBTest do
  use Tempo.SQL.Test.RepoCase

  import Tempo.Ecto.QueryAPI

  defp interval(from_str, to_str) do
    from = Tempo.from_iso8601!(from_str)
    to = Tempo.from_iso8601!(to_str)
    {:ok, iv} = Tempo.Interval.new(from: from, to: to)
    iv
  end

  describe "Tempo.Ecto.Interval end-to-end" do
    test "inserts and reads back a meeting window" do
      window = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")

      meeting =
        %Meeting{name: "Standup", window: window}
        |> Repo.insert!()

      fetched = Repo.get!(Meeting, meeting.id)

      assert %Tempo.Interval{from: %Tempo{}, to: %Tempo{}} = fetched.window
      assert Keyword.get(fetched.window.from.time, :hour) == 9
      assert Keyword.get(fetched.window.to.time, :hour) == 10
    end

    test "stores an open-start window as a range unbounded on the left" do
      until = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, window} = Tempo.Interval.new(from: :undefined, to: until)

      %Meeting{name: "Deadline", window: window} |> Repo.insert!()

      [row] = Repo.all(from m in Meeting, where: m.name == "Deadline")
      assert row.window.from == :undefined
    end

    test "queries with `contains` — meetings whose window contains a point" do
      morning = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      afternoon = interval("2026-06-15T14:00:00", "2026-06-15T15:00:00")

      Repo.insert!(%Meeting{name: "Morning", window: morning})
      Repo.insert!(%Meeting{name: "Afternoon", window: afternoon})

      instant_at_930 = %Postgrex.Range{
        lower: ~U[2026-06-15 09:30:00Z],
        upper: ~U[2026-06-15 09:30:00Z],
        lower_inclusive: true,
        upper_inclusive: true
      }

      names =
        Repo.all(
          from m in Meeting,
            where: contains(m.window, ^instant_at_930),
            select: m.name
        )

      assert names == ["Morning"]
    end

    test "queries with `overlaps` — meetings whose window overlaps a search range" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval("2026-06-15T09:30:00", "2026-06-15T10:30:00")
      c = interval("2026-06-15T14:00:00", "2026-06-15T15:00:00")

      Repo.insert!(%Meeting{name: "A", window: a})
      Repo.insert!(%Meeting{name: "B", window: b})
      Repo.insert!(%Meeting{name: "C", window: c})

      search = interval("2026-06-15T09:45:00", "2026-06-15T10:15:00")
      {:ok, search_range} = Tempo.Ecto.Interval.dump(search)

      names =
        Repo.all(
          from m in Meeting,
            where: overlaps(m.window, ^search_range),
            select: m.name,
            order_by: m.name
        )

      assert names == ["A", "B"]
    end

    test "refuses to insert an interval that violates the storage contract" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      recurring = %{a | recurrence: 5}

      # Dump fails → Ecto raises a ChangeError on insert. This is the
      # system boundary where the storage contract is enforced.
      assert_raise Ecto.ChangeError, fn ->
        Repo.insert!(%Meeting{name: "Recurring", window: recurring})
      end
    end
  end

  describe "Tempo.Ecto.IntervalSet end-to-end" do
    test "inserts and reads back a busy-times multirange" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval("2026-06-15T14:00:00", "2026-06-15T15:00:00")
      {:ok, busy} = Tempo.IntervalSet.new([a, b])

      row = Repo.insert!(%Calendar{owner: "alice", busy_times: busy})
      fetched = Repo.get!(Calendar, row.id)

      assert %Tempo.IntervalSet{intervals: intervals} = fetched.busy_times
      assert length(intervals) == 2
      assert Enum.at(intervals, 0).from.time |> Keyword.get(:hour) == 9
      assert Enum.at(intervals, 1).from.time |> Keyword.get(:hour) == 14
    end

    test "queries with `overlaps` on a multirange column" do
      a = interval("2026-06-15T09:00:00", "2026-06-15T10:00:00")
      b = interval("2026-06-15T14:00:00", "2026-06-15T15:00:00")
      {:ok, alice_busy} = Tempo.IntervalSet.new([a, b])

      c = interval("2026-06-15T11:00:00", "2026-06-15T12:00:00")
      {:ok, bob_busy} = Tempo.IntervalSet.new([c])

      Repo.insert!(%Calendar{owner: "alice", busy_times: alice_busy})
      Repo.insert!(%Calendar{owner: "bob", busy_times: bob_busy})

      search_window = interval("2026-06-15T09:30:00", "2026-06-15T09:45:00")
      {:ok, search_set} = Tempo.IntervalSet.new([search_window])
      {:ok, search_multirange} = Tempo.Ecto.IntervalSet.dump(search_set)

      owners =
        Repo.all(
          from c in Calendar,
            where: overlaps(c.busy_times, ^search_multirange),
            select: c.owner
        )

      assert owners == ["alice"]
    end
  end
end
