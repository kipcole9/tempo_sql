defmodule Tempo.SQL.Test.RepoCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Tempo.SQL.Repo
      alias Tempo.SQL.Test.{Meeting, Calendar}

      import Ecto
      import Ecto.Query
      import Tempo.SQL.Test.RepoCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Tempo.SQL.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Tempo.SQL.Repo, {:shared, self()})
    end

    :ok
  end
end
