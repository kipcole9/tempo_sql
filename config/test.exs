import Config

config :ex_tempo_sql, ecto_repos: [Tempo.SQL.Repo]

config :ex_tempo_sql, Tempo.SQL.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "tempo_sql_test",
  username: System.get_env("PGUSER") || System.get_env("USER"),
  password: System.get_env("PGPASSWORD") || "",
  hostname: System.get_env("PGHOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  types: Tempo.SQL.PostgresTypes,
  priv: "test/support"

config :logger, level: :warning

# Postgrex defaults to Jason for jsonb encoding. Tempo SQL uses
# Erlang's built-in :json module (OTP 27+), so we point Postgrex
# at it here. Applications depending on tempo_sql need the same
# configuration in their own config — the README has a note.
config :postgrex, :json_library, :json
