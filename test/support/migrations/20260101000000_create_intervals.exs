defmodule Tempo.SQL.Repo.Migrations.CreateIntervals do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :name, :string
      add :window, :tstzrange
    end

    create index(:meetings, [:window], using: :gist)

    create table(:calendars) do
      add :owner, :string
      add :busy_times, :tstzmultirange
    end

    create index(:calendars, [:busy_times], using: :gist)
  end
end
