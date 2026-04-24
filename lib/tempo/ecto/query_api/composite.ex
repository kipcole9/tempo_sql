defmodule Tempo.Ecto.QueryAPI.Composite do
  @moduledoc """
  Ecto query fragments for the `tempo_range` and
  `tempo_multirange` composite types — the same Allen-named
  macros as `Tempo.Ecto.QueryAPI`, but auto-unwrapping the
  `(column).range` / `(column).ranges` field so Postgres range
  operators can apply.

  Use these when the column is `Tempo.Ecto.TempoRange` or
  `Tempo.Ecto.TempoMultirange`. Mixing the plain-range macros
  with a composite column produces a SQL error because
  `@>` / `&&` etc. are not defined on composite types directly.

  ## Usage

      import Ecto.Query
      import Tempo.Ecto.QueryAPI.Composite

      from m in Meeting, where: overlaps(m.window, ^iv)

  Right-hand operands are still plain `%Postgrex.Range{}` /
  `%Postgrex.Multirange{}` values, produced via
  `Tempo.Ecto.Interval.dump/3` or
  `Tempo.Ecto.IntervalSet.dump/3`. The *left* operand
  auto-unwraps.

  ## Macros

  Same names and semantics as `Tempo.Ecto.QueryAPI`:

    * `contains/2` — `@>`
    * `overlaps/2` — `&&`
    * `meets/2`    — `-|-`
    * `strictly_before/2` — `<<`
    * `strictly_after/2`  — `>>`

  """

  defmacro contains(left, right) do
    quote do
      fragment("(?).range @> ?", unquote(left), unquote(right))
    end
  end

  defmacro overlaps(left, right) do
    quote do
      fragment("(?).range && ?", unquote(left), unquote(right))
    end
  end

  defmacro meets(left, right) do
    quote do
      fragment("(?).range -|- ?", unquote(left), unquote(right))
    end
  end

  defmacro strictly_before(left, right) do
    quote do
      fragment("(?).range << ?", unquote(left), unquote(right))
    end
  end

  defmacro strictly_after(left, right) do
    quote do
      fragment("(?).range >> ?", unquote(left), unquote(right))
    end
  end
end
