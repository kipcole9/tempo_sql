defmodule Tempo.Ecto.QueryAPI do
  @moduledoc """
  Ecto query fragments for PostgreSQL range operators, named after
  Allen's interval algebra so queries read as English sentences.

  Each macro expands to a `fragment/2` using the corresponding
  PostgreSQL operator. The macros are `require`-able from any
  Ecto query module:

      import Ecto.Query
      import Tempo.Ecto.QueryAPI

      from m in Meeting, where: overlaps(m.window, ^iv)

  The mapping to Postgres operators:

    * `contains/2` → `@>` — "does `a` fully contain `b`?"

    * `overlaps/2` → `&&` — "do `a` and `b` share any instant?"
      Matches Allen's `overlaps`, `overlapped_by`, `starts`,
      `started_by`, `during`, `contains`, `finishes`,
      `finished_by`, `equals` — i.e. any non-disjoint pair.

    * `meets/2` → `-|-` — "is `a` immediately adjacent to `b`?"
      Matches Allen's `meets` and `met_by`.

    * `strictly_before/2` → `<<` — Allen's `precedes`.

    * `strictly_after/2` → `>>` — Allen's `preceded_by`.

  The right-hand operand in each macro should be a `Postgrex.Range`
  or `Postgrex.Multirange` — i.e. either a range literal or a value
  produced by `Tempo.Ecto.Interval.dump/1` /
  `Tempo.Ecto.IntervalSet.dump/1`. The Ecto field type on the left
  handles the conversion automatically when you pin a Tempo value
  via `^` in the query.

  """

  defmacro contains(left, right) do
    quote do
      fragment("? @> ?", unquote(left), unquote(right))
    end
  end

  defmacro overlaps(left, right) do
    quote do
      fragment("? && ?", unquote(left), unquote(right))
    end
  end

  defmacro meets(left, right) do
    quote do
      fragment("? -|- ?", unquote(left), unquote(right))
    end
  end

  defmacro strictly_before(left, right) do
    quote do
      fragment("? << ?", unquote(left), unquote(right))
    end
  end

  defmacro strictly_after(left, right) do
    quote do
      fragment("? >> ?", unquote(left), unquote(right))
    end
  end
end
