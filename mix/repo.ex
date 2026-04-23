defmodule Tempo.SQL.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :ex_tempo_sql,
    adapter: Ecto.Adapters.Postgres
end
