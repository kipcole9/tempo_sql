defmodule Tempo.SQL.Meta do
  @moduledoc """
  JSON encoding and decoding for the `meta` column of the
  `tempo_range` and `tempo_multirange` composite types.

  The range column of a composite carries the queryable span.
  The `meta` column carries everything else Tempo knows that
  `tstzrange` cannot express — qualifications, non-Gregorian
  calendars, zone identifiers, recurrence rules, interval
  metadata, and the implicit-vs-explicit-span distinction.

  On store, the meta is a JSON document with this shape:

      %{
        "v"           => 1,
        "from"        => iso8601_string | null,
        "to"          => iso8601_string | null,
        "recurrence"  => pos_integer | "infinity" | 1,
        "direction"   => 1 | -1,
        "duration"    => iso8601_string | null,
        "repeat_rule" => iso8601_string | null,
        "metadata"    => map            # must be JSON-serialisable
      }

  On load, the endpoints are reconstituted via
  `Tempo.from_iso8601/1`, which faithfully recovers every
  Tempo feature ISO 8601 / ISO 8601-2 / IXDTF can express.

  Encoding uses Erlang's built-in `:json` module (OTP 27+);
  the `jsonb` column type handles storage and indexing on the
  Postgres side.

  """

  @current_version 1

  # Erlang's :json module uses the `:null` atom for JSON null by
  # default. We configure both encode and decode to use Elixir's
  # `nil` instead, so the rest of the codebase never has to
  # distinguish `:null` from `nil`.
  @decode_options %{null: nil}

  @doc "Encoder callback for `:json.encode/2` that treats `nil` as JSON null."
  def nil_aware_encoder(nil, _encode), do: "null"
  def nil_aware_encoder(value, encode), do: :json.encode_value(value, encode)

  @doc "Decoder options for `:json.decode/3` that map JSON null to `nil`."
  def decode_options, do: @decode_options

  @doc "Encode an arbitrary term as a nil-aware JSON binary."
  def encode_json(term) do
    term |> :json.encode(&nil_aware_encoder/2) |> IO.iodata_to_binary()
  end

  @doc "Decode a nil-aware JSON binary. Returns the decoded term directly."
  def decode_json(binary) when is_binary(binary) do
    {decoded, :ok, _rest} = :json.decode(binary, :ok, @decode_options)
    decoded
  end

  @doc """
  Encode a `t:Tempo.Interval.t/0` to a JSON string for storage
  in a `jsonb` column.

  Returns an iolist suitable for handing to Postgrex.
  """
  @spec encode_interval(Tempo.Interval.t()) :: iodata()
  def encode_interval(%Tempo.Interval{} = interval) do
    interval
    |> interval_to_map()
    |> :json.encode(&nil_aware_encoder/2)
  end

  @doc """
  Decode a JSON string (or already-decoded map) back into a
  `t:Tempo.Interval.t/0`.

  Returns `{:ok, interval}` or `{:error, reason}`.
  """
  @spec decode_interval(String.t() | map()) ::
          {:ok, Tempo.Interval.t()} | {:error, term()}
  def decode_interval(json) when is_binary(json) do
    case :json.decode(json, :ok, @decode_options) do
      {map, :ok, _rest} when is_map(map) -> decode_interval(map)
      {other, :ok, _rest} -> {:error, {:invalid_meta_shape, other}}
    end
  end

  def decode_interval(%{} = map) do
    with {:ok, from} <- decode_endpoint(Map.get(map, "from")),
         {:ok, to} <- decode_endpoint(Map.get(map, "to")),
         {:ok, recurrence} <- decode_recurrence(Map.get(map, "recurrence", 1)),
         {:ok, direction} <- decode_direction(Map.get(map, "direction", 1)),
         {:ok, duration} <- decode_duration(Map.get(map, "duration")),
         {:ok, repeat_rule} <- decode_repeat_rule(Map.get(map, "repeat_rule")) do
      {:ok,
       %Tempo.Interval{
         from: from,
         to: to,
         recurrence: recurrence,
         direction: direction,
         duration: duration,
         repeat_rule: repeat_rule,
         metadata: Map.get(map, "metadata", %{}) || %{}
       }}
    end
  end

  # ------------------------------------------------------------------
  # Interval → map
  # ------------------------------------------------------------------

  defp interval_to_map(%Tempo.Interval{} = interval) do
    %{
      "v" => @current_version,
      "from" => encode_endpoint(interval.from),
      "to" => encode_endpoint(interval.to),
      "recurrence" => encode_recurrence(interval.recurrence),
      "direction" => interval.direction,
      "duration" => encode_duration(interval.duration),
      "repeat_rule" => encode_repeat_rule(interval.repeat_rule),
      "metadata" => interval.metadata || %{}
    }
  end

  defp encode_endpoint(:undefined), do: nil
  defp encode_endpoint(nil), do: nil
  defp encode_endpoint(%Tempo{} = tempo), do: Tempo.to_iso8601(tempo)
  defp encode_endpoint(%Tempo.Duration{} = duration), do: Tempo.to_iso8601(duration)

  defp encode_recurrence(:infinity), do: "infinity"
  defp encode_recurrence(n) when is_integer(n), do: n

  defp encode_duration(nil), do: nil
  defp encode_duration(%Tempo.Duration{} = d), do: Tempo.to_iso8601(d)

  defp encode_repeat_rule(nil), do: nil
  defp encode_repeat_rule(%Tempo{} = t), do: Tempo.to_iso8601(t)

  # ------------------------------------------------------------------
  # Map → Interval fields
  # ------------------------------------------------------------------

  defp decode_endpoint(nil), do: {:ok, :undefined}

  defp decode_endpoint(string) when is_binary(string) do
    case Tempo.from_iso8601(string) do
      {:ok, %Tempo{} = tempo} -> {:ok, tempo}
      {:ok, %Tempo.Duration{} = duration} -> {:ok, duration}
      {:ok, other} -> {:error, {:unexpected_endpoint_type, other}}
      {:error, _} = err -> err
    end
  end

  defp decode_recurrence(1), do: {:ok, 1}
  defp decode_recurrence(n) when is_integer(n) and n > 0, do: {:ok, n}
  defp decode_recurrence("infinity"), do: {:ok, :infinity}
  defp decode_recurrence(other), do: {:error, {:invalid_recurrence, other}}

  defp decode_direction(1), do: {:ok, 1}
  defp decode_direction(-1), do: {:ok, -1}
  defp decode_direction(other), do: {:error, {:invalid_direction, other}}

  defp decode_duration(nil), do: {:ok, nil}

  defp decode_duration(string) when is_binary(string) do
    case Tempo.from_iso8601(string) do
      {:ok, %Tempo.Duration{} = duration} -> {:ok, duration}
      {:ok, other} -> {:error, {:unexpected_duration_type, other}}
      {:error, _} = err -> err
    end
  end

  defp decode_repeat_rule(nil), do: {:ok, nil}

  defp decode_repeat_rule(string) when is_binary(string) do
    case Tempo.from_iso8601(string) do
      {:ok, %Tempo{} = tempo} -> {:ok, tempo}
      {:ok, other} -> {:error, {:unexpected_repeat_rule_type, other}}
      {:error, _} = err -> err
    end
  end
end
