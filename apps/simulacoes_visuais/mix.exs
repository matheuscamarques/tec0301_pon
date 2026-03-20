defmodule SimulacoesVisuais.MixProject do
  use Mix.Project

  def project do
    [
      app: :simulacoes_visuais,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SimulacoesVisuais.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment (mix/ for custom Mix tasks).
  defp elixirc_paths(:test), do: ["lib", "mix", "test/support"]
  defp elixirc_paths(_), do: ["lib", "mix"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:broadway, "~> 1.0"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:nx, "~> 0.11"},
      {:axon, "~> 0.8"},
      {:scholar, "~> 0.4"},
      {:nimble_csv, "~> 1.2"},
      {:tec0301_pon, path: "../.."}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      # Phoenix com TSDB + Monte Carlo por omissão (env já definido no shell não é sobrescrito).
      "dev.tsdb": &dev_tsdb_server/1,
      setup: ["deps.get", "assets.setup", "assets.build"],
      "profile.pipeline": ["simulacoes_visuais.profile_workload"],
      "stress.hammer": ["simulacoes_visuais.stress_hammer"],
      "verify.tsdb": ["simulacoes_visuais.verify_tsdb"],
      "verify.bi": ["simulacoes_visuais.verify_bi_queries"],
      "export.ml": ["simulacoes_visuais.export_ml"],
      "import.ml.predictions": ["simulacoes_visuais.ml_import_predictions"],
      "train.ml": ["simulacoes_visuais.ml_train"],
      "retention.tsdb": ["simulacoes_visuais.retention"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "simulacoes_visuais.assets_npm"
      ],
      "assets.build": [
        "compile",
        "tailwind simulacoes_visuais",
        "esbuild simulacoes_visuais"
      ],
      "assets.deploy": [
        "tailwind simulacoes_visuais --minify",
        "esbuild simulacoes_visuais --minify",
        "phx.digest"
      ],
      "ecto.create": ["db.check", "ecto.create"],
      "ecto.reset": ["ecto.drop --force", "ecto.create", "ecto.migrate"],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp dev_tsdb_server(args) do
    put_env_default("SIMULACOES_TSDB_ENABLED", "true")
    put_env_default("AUTO_START_MONTE_CARLO", "true")
    Mix.Task.run("phx.server", args)
  end

  defp put_env_default(name, value) do
    if System.get_env(name) == nil do
      System.put_env(name, value)
    end
  end
end
