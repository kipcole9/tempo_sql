if Code.ensure_loaded?(Ecto.Type) do
  defmodule Tempo.Ecto.Interval do
    @moduledoc """
    Ecto.Type for persisting a `t:Tempo.Interval.t/0` as a
    PostgreSQL `tstzrange` value.

    ## Usage

        schema "meetings" do
          field :window, Tempo.Ecto.Interval
        end

    and in the migration:

        add :window, :tstzrange

    (or use `Tempo.SQL.Migration.add_interval/2`).

    ## Storage contract

    This type refuses to store values it cannot round-trip cleanly.
    `dump/1` returns `{:error, %Tempo.SQL.UnsupportedValueError{}}`
    (via `:error` from Ecto's callback) for:

      * Intervals with a recurrence count (`recurrence != 1`) or a
        `repeat_rule`. Materialise these into a
        `t:Tempo.IntervalSet.t/0` via `Tempo.to_interval/1` and
        store the set as `Tempo.Ecto.IntervalSet` instead.

      * Intervals whose `from` or `to` endpoints are
        `t:Tempo.t/0` values without a full year-month-day-hour-
        minute-second resolution. Materialise via
        `Tempo.to_interval/1` first.

      * Tempo endpoints with a `:qualification` (`:uncertain`,
        `:approximate`), a non-Gregorian calendar, or multi-valued
        token slots (`day_of_week: [1, 3, 5]`, `day: 1..15`).

      * Intervals that are unbounded on both sides. Partial open
        ends (`from: :undefined` or `to: :undefined`) are stored as
        `(,b]` / `[a,)` ranges in Postgres.

    ## Metadata and round-trip

    Round-trip is lossy by design in this first release:

      * `:extended` metadata (zone_id, IXDTF tags) is dropped.
      * `:qualification` cannot be stored (see above).
      * Non-Gregorian calendars are rejected rather than converted.
      * The `:metadata` field on `Tempo.Interval` is dropped.

    Loaded values are always Gregorian-calendar Tempo values at
    UTC (shift `[hour: 0]`, zone_id `"Etc/UTC"`).

    """

    @behaviour Ecto.Type

    alias Tempo.SQL.Conversion

    @impl Ecto.Type
    def type, do: :tstzrange

    @impl Ecto.Type
    def cast(nil), do: {:ok, nil}
    def cast(%Tempo.Interval{} = interval), do: materialise(interval)
    def cast(%Tempo{} = tempo), do: materialise(tempo)

    def cast(%Postgrex.Range{} = range) do
      case Conversion.range_to_interval(range) do
        {:ok, interval} -> {:ok, interval}
        {:error, _} -> :error
      end
    end

    def cast(_), do: :error

    @impl Ecto.Type
    def load(nil), do: {:ok, nil}

    def load(%Postgrex.Range{} = range) do
      case Conversion.range_to_interval(range) do
        {:ok, interval} -> {:ok, interval}
        {:error, _} -> :error
      end
    end

    def load(_), do: :error

    @impl Ecto.Type
    def dump(nil), do: {:ok, nil}

    def dump(%Tempo.Interval{} = interval) do
      case Conversion.interval_to_range(interval) do
        {:ok, range} -> {:ok, range}
        {:error, _} -> :error
      end
    end

    def dump(_), do: :error

    @impl Ecto.Type
    def equal?(a, b), do: a == b

    @impl Ecto.Type
    def embed_as(_), do: :self

    # `cast/1` is lenient about partial Tempo values — it runs them
    # through `Tempo.to_interval/1` to get an explicit span before
    # dumping. A single partial Tempo may materialise to an
    # IntervalSet (for recurrences); those must be stored via
    # `Tempo.Ecto.IntervalSet` and are rejected here.
    defp materialise(%Tempo.Interval{from: %Tempo{}, to: %Tempo{}} = interval), do: {:ok, interval}

    defp materialise(value) do
      case Tempo.to_interval(value) do
        {:ok, %Tempo.Interval{} = interval} -> {:ok, interval}
        {:ok, %Tempo.IntervalSet{}} -> :error
        _ -> :error
      end
    end
  end
end
