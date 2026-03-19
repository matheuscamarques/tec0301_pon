defmodule SimulacoesVisuais.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    tsdb_enabled = Application.get_env(:simulacoes_visuais, :tsdb_enabled, false)

    # Persistência de telemetria é feita no TelemetryPipeline.handle_batch (artigo 14).
    # OEE, anomalias e regras são persistidos por writers que subscrevem PubSub.
    tsdb_children =
      if tsdb_enabled do
        [
          SimulacoesVisuais.Repo,
          SimulacoesVisuais.SmartBrewery.OeeSnapshotWriter,
          SimulacoesVisuais.SmartBrewery.AnomalyEventWriter,
          SimulacoesVisuais.SmartBrewery.RuleEventWriter
        ]
      else
        []
      end

    children =
      [
        SimulacoesVisuaisWeb.Telemetry,
        {DNSCluster,
         query: Application.get_env(:simulacoes_visuais, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: SimulacoesVisuais.PubSub},
        SimulacoesVisuais.SmartBreweryBridge,
        # Broadway + GenStage (artigo 06): quando ativo, FactBroadcaster envia ao producer; backpressure e batching.
        SimulacoesVisuais.SmartBrewery.TelemetryPipeline,
        {SimulacoesVisuais.SmartBreweryTelemetryBatcher,
         Application.get_env(:simulacoes_visuais, :telemetry_batcher, [])},
        {SimulacoesVisuais.LiveViewEventBatcher,
         Application.get_env(:simulacoes_visuais, :live_view_batcher, [])},
        SimulacoesVisuais.SmartBrewery.EMA,
        SimulacoesVisuais.SmartBrewery.OEE,
        SimulacoesVisuais.SmartBreweryRegraNotifier,
        SimulacoesVisuais.SmartBreweryFactBroadcaster,
        SimulacoesVisuais.SmartBrewery.FBE11SmartGrid,
        SimulacoesVisuais.SmartBrewery.FBE08Markov,
        SimulacoesVisuais.SmartBrewery.FBE10Markov,
        SimulacoesVisuais.SmartBrewery.FBE03Darcy,
        SimulacoesVisuais.SmartBrewery.FBE06Fermentation,
        SimulacoesVisuais.SmartBrewery.FBE07Fermentation,
        {SimulacoesVisuais.SmartBreweryMonteCarlo,
         [interval_ms: Application.get_env(:simulacoes_visuais, :monte_carlo_interval_ms, 1_500)]},
        # Repo + TelemetryWriter quando tsdb_enabled (Docker ou dev com DB)
        tsdb_children,
        # Start to serve requests, typically the last entry
        SimulacoesVisuaisWeb.Endpoint
      ]
      |> List.flatten()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SimulacoesVisuais.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SimulacoesVisuaisWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
