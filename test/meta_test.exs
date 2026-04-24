defmodule Tempo.SQL.MetaTest do
  use ExUnit.Case, async: true

  alias Tempo.SQL.Meta

  describe "encode/decode round-trip — the shapes the plain-range types reject" do
    test "year-resolution implicit span survives" do
      year = Tempo.from_iso8601!("2026")
      {:ok, interval} = Tempo.Interval.new(from: year, to: Tempo.from_iso8601!("2027"))

      json = interval |> Meta.encode_interval() |> IO.iodata_to_binary()
      {:ok, loaded} = Meta.decode_interval(json)

      # The loaded `from` endpoint still has only a year token.
      assert loaded.from.time == [year: 2026]
      assert loaded.to.time == [year: 2027]
    end

    test "qualified (uncertain) endpoint survives" do
      {:ok, interval} = Tempo.from_iso8601("1984?/2004~")

      json = interval |> Meta.encode_interval() |> IO.iodata_to_binary()
      {:ok, loaded} = Meta.decode_interval(json)

      assert loaded.from.qualification == :uncertain
      assert loaded.to.qualification == :approximate
    end

    test "recurrence rule survives" do
      {:ok, interval} = Tempo.from_iso8601("R5/2022-01-01/P1M")

      json = interval |> Meta.encode_interval() |> IO.iodata_to_binary()
      {:ok, loaded} = Meta.decode_interval(json)

      assert loaded.recurrence == 5
      assert %Tempo.Duration{} = loaded.duration
    end

    test "user metadata passes through when JSON-serialisable" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T10:00:00")

      interval = %Tempo.Interval{
        from: from,
        to: to,
        metadata: %{"source" => "calendar-import", "priority" => 3}
      }

      json = interval |> Meta.encode_interval() |> IO.iodata_to_binary()
      {:ok, loaded} = Meta.decode_interval(json)

      assert loaded.metadata == %{"source" => "calendar-import", "priority" => 3}
    end
  end

  describe "encode_interval/1" do
    test "produces a string with the expected top-level keys" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T10:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)

      decoded = interval |> Meta.encode_interval() |> IO.iodata_to_binary() |> Meta.decode_json()

      assert Map.has_key?(decoded, "v")
      assert Map.has_key?(decoded, "from")
      assert Map.has_key?(decoded, "to")
      assert Map.has_key?(decoded, "recurrence")
      assert decoded["v"] == 1
      assert decoded["recurrence"] == 1
      assert decoded["direction"] == 1
    end

    test "unbounded endpoints encode as null" do
      to = Tempo.from_iso8601!("2026-06-15T10:00:00")
      {:ok, interval} = Tempo.Interval.new(from: :undefined, to: to)

      decoded = interval |> Meta.encode_interval() |> IO.iodata_to_binary() |> Meta.decode_json()

      assert decoded["from"] == nil
      assert is_binary(decoded["to"])
    end
  end
end
