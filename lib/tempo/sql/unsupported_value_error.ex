defmodule Tempo.SQL.UnsupportedValueError do
  @moduledoc """
  Raised (or returned from `cast/2`) when a Tempo value cannot be
  stored in a PostgreSQL range type.

  See the "Storage contract" section of the README for the full
  list of cases this error is raised for — the common ones are
  recurrence rules, uncertain/approximate qualifications, non-
  Gregorian calendars, time-zone shifts, and partial time slots
  (year-only or year-month-only values that have not been
  materialised to an explicit span via `Tempo.to_interval/1`).

  """

  defexception [:reason, :value, :message]

  @type t :: %__MODULE__{
          reason: atom(),
          value: term(),
          message: String.t()
        }

  @impl true
  def exception(fields) do
    reason = Keyword.fetch!(fields, :reason)
    value = Keyword.get(fields, :value)
    message = Keyword.get(fields, :message) || default_message(reason, value)

    %__MODULE__{reason: reason, value: value, message: message}
  end

  defp default_message(:recurrence, _),
    do: "recurrence rules cannot be stored in a PostgreSQL range"

  defp default_message(:repeat_rule, _), do: "repeat rules cannot be stored in a PostgreSQL range"

  defp default_message(:qualification, _),
    do: "qualified Tempo values (uncertain/approximate) cannot be stored in a PostgreSQL range"

  defp default_message(:non_gregorian_calendar, _),
    do: "non-Gregorian calendars are not supported for PostgreSQL range storage"

  defp default_message(:shift, _),
    do: "zone-shifted Tempo values cannot be stored directly; convert to UTC first"

  defp default_message(:multi_valued_slot, _),
    do:
      "Tempo values with multi-valued token slots (lists or ranges) cannot be stored in a PostgreSQL range"

  defp default_message(:partial_resolution, _),
    do: "partial Tempo values must be materialised via Tempo.to_interval/1 before storage"

  defp default_message(:empty_set, _),
    do: "empty IntervalSet cannot be stored as a tstzmultirange with any occurrences"

  defp default_message(:open_ended_member, _),
    do:
      "IntervalSet members must be bounded; use Tempo.Ecto.Interval for a single open-ended range"

  defp default_message(reason, value),
    do: "Tempo value cannot be stored in a PostgreSQL range (#{reason}): #{inspect(value)}"
end
