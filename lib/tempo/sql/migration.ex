defmodule Tempo.SQL.Migration do
  @moduledoc """
  Ecto migration helpers for the Tempo PostgreSQL range types.

  These helpers wrap the underlying Postgres types — `tstzrange`
  and `tstzmultirange` — under Tempo-flavoured names, so a
  migration reads in the same vocabulary as the schema:

      import Tempo.SQL.Migration

      create table(:meetings) do
        add_interval :window
        add_interval_set :busy, null: false
      end

      create_interval_index :meetings, :window

  All helpers are thin delegates to `Ecto.Migration.add/3` and
  `Ecto.Migration.index/3` — callers can also write the raw
  `add :window, :tstzrange` form if they prefer.

  """

  @doc """
  Add a `tstzrange` column for a `Tempo.Ecto.Interval` field.

  ### Arguments

    * `field` is the column name as an atom.

    * `options` are passed through to `Ecto.Migration.add/3` — for
      example `null: false`, `default: ...`.

  ### Examples

      add_interval :window
      add_interval :window, null: false

  """
  defmacro add_interval(field, options \\ []) do
    quote bind_quoted: [field: field, options: options] do
      Ecto.Migration.add(field, :tstzrange, options)
    end
  end

  @doc """
  Add a `tstzmultirange` column for a `Tempo.Ecto.IntervalSet`
  field.

  Requires PostgreSQL 14 or later.

  ### Arguments

    * `field` is the column name as an atom.

    * `options` are passed through to `Ecto.Migration.add/3`.

  ### Examples

      add_interval_set :busy_times
      add_interval_set :free_slots, null: false

  """
  defmacro add_interval_set(field, options \\ []) do
    quote bind_quoted: [field: field, options: options] do
      Ecto.Migration.add(field, :tstzmultirange, options)
    end
  end

  @doc """
  Create a GiST index on a `tstzrange` or `tstzmultirange` column.

  Range-operator queries (`@>`, `&&`, `-|-`) are only fast under a
  GiST index — this helper wraps `create index(..., using: :gist)`.

  ### Arguments

    * `table` is the table name.

    * `column` is the range column to index.

    * `options` are passed through to `Ecto.Migration.index/3`.

  ### Examples

      create_interval_index :meetings, :window

  """
  defmacro create_interval_index(table, column, options \\ []) do
    quote bind_quoted: [table: table, column: column, options: options] do
      options = Keyword.put_new(options, :using, :gist)
      Ecto.Migration.create(Ecto.Migration.index(table, [column], options))
    end
  end
end
