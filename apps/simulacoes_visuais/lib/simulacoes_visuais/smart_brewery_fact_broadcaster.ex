defmodule SimulacoesVisuais.SmartBreweryFactBroadcaster do
  @moduledoc """
  Faz a ponte entre as notificações do PON (Registry do `tec0301_pon`) e o PubSub
  da aplicação Phoenix (`SimulacoesVisuais.PubSub`), para consumo pela LiveView.

  Prática artigo 06: hot path usa apenas handle_info e GenStage.cast ou Batcher.push
  (assíncronos); nenhum handle_call no fluxo de telemetria.
  """

  use GenServer

  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Application.ensure_all_started(:tec0301_pon)

    fatos = Tec0301Pon.Examples.SmartBrewery.fatos_names()

    Enum.each(fatos, fn nome_do_fato ->
      Registry.register(Tec0301Pon.PON.PubSub, nome_do_fato, [])
    end)

    push_lv? = Application.get_env(:simulacoes_visuais, :push_liveview_telemetry, true)

    Logger.info(
      "[SmartBreweryFactBroadcaster] Inscrito em #{length(fatos)} fatos via Tec0301Pon.PON.PubSub."
    )

    {:ok,
     %{
       fatos: fatos,
       producer_pid: resolve_producer_pid(),
       producer_ticks: 0,
       push_liveview_telemetry: push_lv?,
       nil_producer_log_ms: 0
     }}
  end

  @impl true
  def handle_info({:notificacao, nome_do_fato, novo_valor}, state) do
    state = push_telemetry_for_fact(state, nome_do_fato, novo_valor)
    {:noreply, state}
  end

  def handle_info({:notificacoes_lote, updates}, state) when is_map(updates) do
    state =
      Enum.reduce(updates, state, fn {nome_do_fato, novo_valor}, st ->
        push_telemetry_for_fact(st, nome_do_fato, novo_valor)
      end)

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @producer_refresh_every 2_000
  @fallback_log_interval_ms 30_000

  defp push_telemetry_for_fact(state, nome_do_fato, novo_valor) do
    {producer_pid, state} = producer_pid_for_cast(state)

    state =
      if producer_pid do
        GenStage.cast(producer_pid, {:event, nome_do_fato, novo_valor})
        state
      else
        SimulacoesVisuais.SmartBreweryTelemetryBatcher.push(nome_do_fato, novo_valor)
        maybe_log_broadway_fallback(state)
      end

    if Map.get(state, :push_liveview_telemetry, true) do
      SimulacoesVisuais.LiveViewEventBatcher.push(nome_do_fato, novo_valor)
    end

    state
  end

  defp maybe_log_broadway_fallback(state) do
    now = System.monotonic_time(:millisecond)
    last = Map.get(state, :nil_producer_log_ms, 0)

    if now - last >= @fallback_log_interval_ms do
      Logger.warning(
        "[SmartBreweryFactBroadcaster] Broadway producer unavailable; using SmartBreweryTelemetryBatcher fallback (TSDB via batcher flush when :tsdb_enabled)"
      )

      Map.put(state, :nil_producer_log_ms, now)
    else
      state
    end
  end

  defp producer_pid_for_cast(%{producer_pid: pid, producer_ticks: n} = state)
       when is_pid(pid) and n < @producer_refresh_every do
    {pid, %{state | producer_ticks: n + 1}}
  end

  defp producer_pid_for_cast(state) do
    pid = resolve_producer_pid()
    {pid, %{state | producer_pid: pid, producer_ticks: 0}}
  end

  defp resolve_producer_pid do
    try do
      case Broadway.producer_names(SimulacoesVisuais.SmartBrewery.TelemetryPipeline) do
        [first_name | _] -> Process.whereis(first_name)
        [] -> nil
      end
    rescue
      _ -> nil
    end
  end
end
