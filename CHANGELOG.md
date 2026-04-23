# Changelog

All notable changes to `ex_tempo_sql` are documented here, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] — Initial release

### Highlights

Tempo SQL persists Tempo intervals and interval sets as PostgreSQL range types, wiring the half-open `[from, to)` convention through to `tstzrange` / `tstzmultirange` natively.

**Ecto types.** `Tempo.Ecto.Interval` stores a `%Tempo.Interval{}` as `tstzrange`; `Tempo.Ecto.IntervalSet` stores a `%Tempo.IntervalSet{}` as `tstzmultirange` (PG 14+); `Tempo.Ecto.Tempo` materialises a bare `%Tempo{}` implicit span before delegating to the interval type.

**Storage contract.** Each type is explicit about what it refuses to store: recurrence rules, qualifications, non-Gregorian calendars, multi-valued token slots, and ordinal/week-date endpoints all return `:error` from `dump/1` rather than silently losing information. See the "Storage contract" section of the README.

**Migration helpers.** `Tempo.SQL.Migration` exposes `add_interval/2`, `add_interval_set/2`, and `create_interval_index/3`. Range queries require GiST indexes for speed; the helper handles that.

**Query API.** `Tempo.Ecto.QueryAPI` wraps Postgres range operators (`@>`, `&&`, `-|-`, `<<`, `>>`) under Allen's interval-algebra names — `contains`, `overlaps`, `meets`, `strictly_before`, `strictly_after`.

**Round-trip note.** Round 1 is lossy on metadata: `Tempo.Interval.metadata`, `Tempo.IntervalSet.metadata`, Tempo `:extended` metadata, and the implicit-vs-explicit-span distinction are all dropped on store. A future release will add a `:text` (ISO 8601) variant for callers who need perfect round-trip.
