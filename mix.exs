defmodule Tempo.Sql.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ex_tempo_sql,
      version: @version,
      elixir: "~> 1.17",
      name: "Tempo SQL",
      source_url: "https://github.com/kipcole9/tempo_sql",
      docs: docs(),
      deps: deps(),
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: ~w(ecto ecto_sql postgrex ex_tempo)a
      ]
    ]
  end

  def description do
    "Ecto types and migration helpers for persisting Tempo intervals " <>
      "and interval sets as PostgreSQL tstzrange/tstzmultirange values."
  end

  def package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/kipcole9/tempo_sql",
        "Readme" => "https://github.com/kipcole9/tempo_sql/blob/v#{@version}/README.md",
        "Changelog" => "https://github.com/kipcole9/tempo_sql/blob/v#{@version}/CHANGELOG.md"
      },
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      formatters: ["html"]
    ]
  end

  defp aliases do
    [
      test: ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp deps do
    [
      {:ex_tempo, path: "../tempo"},
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.19"},
      {:ex_doc, "~> 0.30", runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "mix", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "mix"]
  defp elixirc_paths(_), do: ["lib"]
end
