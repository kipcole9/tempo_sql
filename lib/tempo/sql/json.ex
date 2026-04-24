defmodule Tempo.SQL.JSON do
  @moduledoc """
  Shim module that adapts Erlang's built-in `:json` (OTP 27+) to
  Postgrex's expected JSON-library interface.

  Postgrex's `jsonb` extension calls
  `library.encode_to_iodata!/1` and `library.decode!/1` (the
  shapes Jason exposes). Erlang's `:json` exposes `encode/2` and
  `decode/3`, so this module bridges the two. It also configures
  `nil` ↔ JSON null translation in both directions, sparing
  application code from the `:null` atom the raw `:json` module
  returns.

  ## Use from Postgrex

      Postgrex.Types.define(MyApp.PostgresTypes, [], json: Tempo.SQL.JSON)

  """

  alias Tempo.SQL.Meta

  @doc "Postgrex-compatible encoder. Returns iodata."
  def encode_to_iodata!(term) do
    :json.encode(term, &Meta.nil_aware_encoder/2)
  end

  @doc "Postgrex-compatible decoder."
  def decode!(binary) when is_binary(binary) do
    {decoded, :ok, _rest} = :json.decode(binary, :ok, Meta.decode_options())
    decoded
  end
end
