defmodule Tempo.SQL do
  @moduledoc """
  Top-level namespace for `ex_tempo_sql` — Ecto types and migration
  helpers that persist Tempo values as PostgreSQL range types.

  See the README for the installation walkthrough and the storage
  contract that spells out which Tempo values round-trip cleanly.

  The entry-point modules are:

    * `Tempo.Ecto.Interval` — stores a `t:Tempo.Interval.t/0` as
      `tstzrange`.

    * `Tempo.Ecto.IntervalSet` — stores a `t:Tempo.IntervalSet.t/0`
      as `tstzmultirange`.

    * `Tempo.Ecto.Tempo` — stores a bare `t:Tempo.t/0` by
      materialising it through `Tempo.to_interval/1` and then
      delegating to `Tempo.Ecto.Interval`.

    * `Tempo.SQL.Migration` — `add :window, Tempo.Interval` helper
      for Ecto migrations.

    * `Tempo.Ecto.QueryAPI` — Allen-named query fragments
      (`contains/2`, `overlaps/2`, `meets/2`) backed by Postgres
      range operators.

  """
end
