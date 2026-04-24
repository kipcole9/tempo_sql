# Defines a Postgrex type registry that uses Erlang's built-in
# :json module for jsonb encoding/decoding instead of Postgrex's
# Jason default. Applications depending on tempo_sql should
# either use this types module directly:
#
#     config :my_app, MyApp.Repo, types: Tempo.SQL.PostgresTypes
#
# or define their own via `Postgrex.Types.define/3` with the
# same `json: :json` option.
#
# `Postgrex.Types.define/3` defines the module itself — we don't
# wrap it in a `defmodule`.

Postgrex.Types.define(Tempo.SQL.PostgresTypes, [], json: Tempo.SQL.JSON)
