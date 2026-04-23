import Config

config :ex_tempo_sql, ecto_repos: [Tempo.SQL.Repo]

config :ex_tempo_sql, Tempo.SQL.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "tempo_sql_test",
  username: System.get_env("PGUSER") || System.get_env("USER"),
  password: System.get_env("PGPASSWORD") || "",
  hostname: System.get_env("PGHOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support"

config :logger, level: :warning
