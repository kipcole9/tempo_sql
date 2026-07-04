defmodule Tempo.Ecto.IntervalTest do
  use ExUnit.Case, async: true

  alias Tempo.Ecto.Interval

  @default_params %{resolution: :second}

  describe "type/1" do
    test "reports tstzrange" do
      assert Interval.type(@default_params) == :tstzrange
    end
  end

  describe "init/1" do
    test "defaults :resolution to :second" do
      assert Interval.init([]) == %{resolution: :second}
    end

    test "accepts valid resolutions" do
      for r <- [:year, :month, :day, :hour, :minute, :second] do
        assert Interval.init(resolution: r) == %{resolution: r}
      end
    end

    test "rejects invalid resolutions" do
      assert_raise ArgumentError, fn -> Interval.init(resolution: :century) end
      assert_raise ArgumentError, fn -> Interval.init(resolution: "year") end
    end
  end

  describe "dump/3 — the storable shape" do
    test "dumps a fully-anchored %Tempo.Interval{} as a Postgrex.Range in UTC" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)

      assert {:ok, %Postgrex.Range{} = range} = Interval.dump(interval, nil, @default_params)
      assert %DateTime{year: 2026, month: 6, day: 15, hour: 9} = range.lower
      assert %DateTime{year: 2026, month: 6, day: 15, hour: 17} = range.upper
      assert range.lower_inclusive == true
      assert range.upper_inclusive == false
    end

    test "dumps an open-start interval as a Range with :unbound lower" do
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: :undefined, to: to)

      assert {:ok, %Postgrex.Range{lower: :unbound}} =
               Interval.dump(interval, nil, @default_params)
    end

    test "dumps an open-end interval as a Range with :unbound upper" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: :undefined)

      assert {:ok, %Postgrex.Range{upper: :unbound}} =
               Interval.dump(interval, nil, @default_params)
    end

    test "returns nil passthrough" do
      assert {:ok, nil} = Interval.dump(nil, nil, @default_params)
    end
  end

  describe "dump/3 — the contract refusal cases" do
    test "refuses an interval with a recurrence count" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)
      recurring = %{interval | recurrence: 5}

      assert :error = Interval.dump(recurring, nil, @default_params)
    end

    test "refuses an interval with a repeat rule" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)
      rule = %Tempo{time: [year: 2026]}

      assert :error = Interval.dump(%{interval | repeat_rule: rule}, nil, @default_params)
    end

    test "refuses a fully-unbounded interval" do
      {:ok, interval} = Tempo.Interval.new(from: :undefined, to: :undefined, duration: nil)
      assert :error = Interval.dump(interval, nil, @default_params)
    end

    test "accepts a year-only Tempo endpoint — fills in calendar defaults" do
      partial = %Tempo{time: [year: 2026]}
      to = Tempo.from_iso8601!("2027-01-01T00:00:00")
      {:ok, interval} = Tempo.Interval.new(from: partial, to: to)

      assert {:ok, %Postgrex.Range{lower: ~U[2026-01-01 00:00:00Z]}} =
               Interval.dump(interval, nil, @default_params)
    end

    test "refuses an ordinal-date Tempo endpoint (must be materialised first)" do
      ordinal = %Tempo{time: [year: 2026, day: 75]}
      to = Tempo.from_iso8601!("2027-01-01T00:00:00")
      {:ok, interval} = Tempo.Interval.new(from: ordinal, to: to)

      assert :error = Interval.dump(interval, nil, @default_params)
    end

    test "refuses a non-%Tempo.Interval{} value" do
      assert :error = Interval.dump("not a range", nil, @default_params)
      assert :error = Interval.dump(42, nil, @default_params)
    end
  end

  describe "load/3 — default :second resolution" do
    test "loads a Postgrex.Range back into a %Tempo.Interval{}" do
      range = %Postgrex.Range{
        lower: ~U[2026-06-15 09:00:00Z],
        upper: ~U[2026-06-15 17:00:00Z],
        lower_inclusive: true,
        upper_inclusive: false
      }

      assert {:ok, %Tempo.Interval{from: %Tempo{}, to: %Tempo{}} = interval} =
               Interval.load(range, nil, @default_params)

      assert Keyword.get(interval.from.time, :year) == 2026
      assert Keyword.get(interval.from.time, :hour) == 9
      assert Keyword.get(interval.to.time, :hour) == 17
    end

    test "loads an unbound lower as :undefined" do
      range = %Postgrex.Range{
        lower: :unbound,
        upper: ~U[2026-06-15 17:00:00Z]
      }

      assert {:ok, %Tempo.Interval{from: :undefined}} = Interval.load(range, nil, @default_params)
    end

    test "returns nil passthrough" do
      assert {:ok, nil} = Interval.load(nil, nil, @default_params)
    end
  end

  describe "load/3 — :resolution option truncates endpoints" do
    test "resolution: :year strips down to year" do
      params = Interval.init(resolution: :year)

      range = %Postgrex.Range{
        lower: ~U[2026-01-01 00:00:00Z],
        upper: ~U[2027-01-01 00:00:00Z],
        lower_inclusive: true,
        upper_inclusive: false
      }

      {:ok, interval} = Interval.load(range, nil, params)

      assert interval.from.time == [year: 2026]
      assert interval.to.time == [year: 2027]
    end

    test "resolution: :month strips down to year+month" do
      params = Interval.init(resolution: :month)

      range = %Postgrex.Range{
        lower: ~U[2026-06-01 00:00:00Z],
        upper: ~U[2026-07-01 00:00:00Z]
      }

      {:ok, interval} = Interval.load(range, nil, params)

      assert interval.from.time == [year: 2026, month: 6]
      assert interval.to.time == [year: 2026, month: 7]
    end

    test "resolution: :day strips down to year+month+day" do
      params = Interval.init(resolution: :day)

      range = %Postgrex.Range{
        lower: ~U[2026-06-15 00:00:00Z],
        upper: ~U[2026-06-16 00:00:00Z]
      }

      {:ok, interval} = Interval.load(range, nil, params)

      assert interval.from.time == [year: 2026, month: 6, day: 15]
      assert interval.to.time == [year: 2026, month: 6, day: 16]
    end

    test "resolution: :hour keeps down to hour" do
      params = Interval.init(resolution: :hour)

      range = %Postgrex.Range{
        lower: ~U[2026-06-15 09:00:00Z],
        upper: ~U[2026-06-15 10:00:00Z]
      }

      {:ok, interval} = Interval.load(range, nil, params)

      assert interval.from.time == [year: 2026, month: 6, day: 15, hour: 9]
      assert interval.to.time == [year: 2026, month: 6, day: 15, hour: 10]
    end
  end

  describe "load/3 — bracket normalisation" do
    test "[] closed range shifts upper by one second to [)" do
      range = %Postgrex.Range{
        lower: ~U[2026-06-15 09:00:00Z],
        upper: ~U[2026-06-15 09:59:59Z],
        lower_inclusive: true,
        upper_inclusive: true
      }

      {:ok, interval} = Interval.load(range, nil, @default_params)

      assert Keyword.get(interval.to.time, :minute) == 0
      assert Keyword.get(interval.to.time, :hour) == 10
    end

    test "(] range shifts both endpoints by one second to [)" do
      range = %Postgrex.Range{
        lower: ~U[2026-06-15 08:59:59Z],
        upper: ~U[2026-06-15 09:59:59Z],
        lower_inclusive: false,
        upper_inclusive: true
      }

      {:ok, interval} = Interval.load(range, nil, @default_params)

      assert Keyword.get(interval.from.time, :hour) == 9
      assert Keyword.get(interval.from.time, :minute) == 0
      assert Keyword.get(interval.to.time, :hour) == 10
    end

    test "() open range shifts lower by one second to [)" do
      range = %Postgrex.Range{
        lower: ~U[2026-06-15 08:59:59Z],
        upper: ~U[2026-06-15 10:00:00Z],
        lower_inclusive: false,
        upper_inclusive: false
      }

      {:ok, interval} = Interval.load(range, nil, @default_params)

      assert Keyword.get(interval.from.time, :hour) == 9
      assert Keyword.get(interval.from.time, :minute) == 0
      assert Keyword.get(interval.to.time, :hour) == 10
    end
  end

  describe "cast/2 — the input-accepting surface" do
    test "accepts a %Tempo.Interval{} unchanged" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, interval} = Tempo.Interval.new(from: from, to: to)

      assert {:ok, ^interval} = Interval.cast(interval, @default_params)
    end

    test "materialises a bare %Tempo{} via Tempo.to_interval/1" do
      tempo = Tempo.from_iso8601!("2026-06-15")

      assert {:ok, %Tempo.Interval{from: %Tempo{}, to: %Tempo{}}} =
               Interval.cast(tempo, @default_params)
    end

    test "accepts a Postgrex.Range" do
      range = %Postgrex.Range{
        lower: ~U[2026-06-15 09:00:00Z],
        upper: ~U[2026-06-15 17:00:00Z]
      }

      assert {:ok, %Tempo.Interval{}} = Interval.cast(range, @default_params)
    end

    test "rejects unknown input" do
      assert :error = Interval.cast("2026", @default_params)
      assert :error = Interval.cast(%{random: "map"}, @default_params)
    end
  end

  describe "round-trip" do
    test "an anchored interval dumps and loads back with the same endpoints" do
      from = Tempo.from_iso8601!("2026-06-15T09:00:00")
      to = Tempo.from_iso8601!("2026-06-15T17:00:00")
      {:ok, original} = Tempo.Interval.new(from: from, to: to)

      {:ok, range} = Interval.dump(original, nil, @default_params)
      {:ok, loaded} = Interval.load(range, nil, @default_params)

      assert Keyword.get(loaded.from.time, :year) == 2026
      assert Keyword.get(loaded.from.time, :hour) == 9
      assert Keyword.get(loaded.to.time, :hour) == 17
    end
  end
end
