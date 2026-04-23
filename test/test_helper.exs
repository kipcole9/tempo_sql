{:ok, _} = Tempo.SQL.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(Tempo.SQL.Repo, :manual)

ExUnit.start()
