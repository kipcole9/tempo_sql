if Code.ensure_loaded?(Ecto.Type) do
  defmodule Tempo.Ecto.Tempo do
    @moduledoc """
    Ecto.Type for persisting a bare `t:Tempo.t/0` as a PostgreSQL
    `tstzrange`.

    A bare Tempo value is an *implicit* span — `~o"2026Y"` spans
    the whole of 2026, `~o"2026Y-06M"` spans June 2026. This type
    materialises the implicit span via `Tempo.to_interval/1` and
    then delegates to `Tempo.Ecto.Interval`.

    ## Usage

        schema "years" do
          field :reporting_year, Tempo.Ecto.Tempo
        end

    and in the migration:

        add :reporting_year, :tstzrange

    ## Round-trip caveat

    *Implicit spans do not round-trip as implicit spans.* A stored
    `~o"2026Y"` loads back as a fully-materialised
    `%Tempo.Interval{from: 2026-01-01T00:00:00Z, to: 2027-01-01T00:00:00Z}`
    — there is no way to recover "it was just a year token" from a
    `tstzrange`. Load the column into `Tempo.Ecto.Interval` rather
    than `Tempo.Ecto.Tempo` if you want a `%Tempo.Interval{}` back;
    loading into this type will succeed but return an `Interval`
    (the cast widens).

    Tempo values that materialise to an `IntervalSet` (any value
    with a recurrence rule) are rejected — store those in a
    `Tempo.Ecto.IntervalSet` column instead.

    """

    @behaviour Ecto.Type

    @impl Ecto.Type
    def type, do: :tstzrange

    @impl Ecto.Type
    def cast(nil), do: {:ok, nil}
    def cast(%Tempo{} = tempo), do: materialise(tempo)
    def cast(%Tempo.Interval{} = interval), do: {:ok, interval}

    def cast(%Postgrex.Range{} = range) do
      Tempo.Ecto.Interval.cast(range)
    end

    def cast(_), do: :error

    @impl Ecto.Type
    def load(value), do: Tempo.Ecto.Interval.load(value)

    @impl Ecto.Type
    def dump(nil), do: {:ok, nil}
    def dump(%Tempo{} = tempo) do
      case materialise(tempo) do
        {:ok, interval} -> Tempo.Ecto.Interval.dump(interval)
        :error -> :error
      end
    end

    def dump(%Tempo.Interval{} = interval), do: Tempo.Ecto.Interval.dump(interval)
    def dump(_), do: :error

    @impl Ecto.Type
    def equal?(a, b), do: a == b

    @impl Ecto.Type
    def embed_as(_), do: :self

    defp materialise(%Tempo{} = tempo) do
      case Tempo.to_interval(tempo) do
        {:ok, %Tempo.Interval{} = interval} -> {:ok, interval}
        {:ok, %Tempo.IntervalSet{}} -> :error
        _ -> :error
      end
    end
  end
end
