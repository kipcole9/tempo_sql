if Code.ensure_loaded?(Ecto.Type) do
  defmodule Tempo.Ecto.IntervalSet do
    @moduledoc """
    Ecto.Type for persisting a `t:Tempo.IntervalSet.t/0` as a
    PostgreSQL `tstzmultirange` value (PostgreSQL 14+).

    ## Usage

        schema "alice_calendar" do
          field :busy_times, Tempo.Ecto.IntervalSet
        end

    and in the migration:

        add :busy_times, :tstzmultirange

    (or use `Tempo.SQL.Migration.add_interval_set/2`).

    ## Storage contract

    Every member interval must satisfy the same contract as
    `Tempo.Ecto.Interval` — see that module for the full list.
    In addition:

      * The set must be non-empty. An empty multirange round-trips
        as `'{}'::tstzmultirange`; use a NULL column if you want to
        represent "no set".

      * Every member interval must be bounded on both ends
        (Tempo.IntervalSet already enforces this via its own
        validation — the constructor rejects `:undefined`
        endpoints).

    Metadata (`:metadata` on the set itself) is dropped on storage.

    """

    @behaviour Ecto.Type

    alias Tempo.SQL.Conversion
    alias Tempo.SQL.UnsupportedValueError

    @impl Ecto.Type
    def type, do: :tstzmultirange

    @impl Ecto.Type
    def cast(nil), do: {:ok, nil}
    def cast(%Tempo.IntervalSet{} = set), do: {:ok, set}

    def cast(%Postgrex.Multirange{} = multirange) do
      case multirange_to_set(multirange) do
        {:ok, set} -> {:ok, set}
        {:error, _} -> :error
      end
    end

    def cast(intervals) when is_list(intervals) do
      case Tempo.IntervalSet.new(intervals) do
        {:ok, set} -> {:ok, set}
        {:error, _} -> :error
      end
    end

    def cast(_), do: :error

    @impl Ecto.Type
    def load(nil), do: {:ok, nil}

    def load(%Postgrex.Multirange{} = multirange) do
      case multirange_to_set(multirange) do
        {:ok, set} -> {:ok, set}
        {:error, _} -> :error
      end
    end

    def load(_), do: :error

    @impl Ecto.Type
    def dump(nil), do: {:ok, nil}

    def dump(%Tempo.IntervalSet{intervals: []}), do: :error

    def dump(%Tempo.IntervalSet{intervals: intervals}) do
      case dump_members(intervals, []) do
        {:ok, ranges} -> {:ok, %Postgrex.Multirange{ranges: ranges}}
        :error -> :error
      end
    end

    def dump(_), do: :error

    @impl Ecto.Type
    def equal?(a, b), do: a == b

    @impl Ecto.Type
    def embed_as(_), do: :self

    defp dump_members([], acc), do: {:ok, Enum.reverse(acc)}

    defp dump_members([interval | rest], acc) do
      case Conversion.interval_to_range(interval) do
        {:ok, range} -> dump_members(rest, [range | acc])
        {:error, _} -> :error
      end
    end

    defp multirange_to_set(%Postgrex.Multirange{ranges: ranges}) do
      with {:ok, intervals} <- load_members(ranges, []),
           {:ok, set} <- Tempo.IntervalSet.new(intervals) do
        {:ok, set}
      else
        {:error, _} = err -> err
        :error -> {:error, UnsupportedValueError.exception(reason: :invalid_multirange, value: ranges)}
      end
    end

    defp load_members([], acc), do: {:ok, Enum.reverse(acc)}

    defp load_members([range | rest], acc) do
      case Conversion.range_to_interval(range) do
        {:ok, interval} -> load_members(rest, [interval | acc])
        {:error, _} = err -> err
      end
    end
  end
end
