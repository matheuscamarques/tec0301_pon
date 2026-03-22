defmodule Tec0301Pon.PON.Regra do
  @moduledoc """
  GenServer que representa uma Regra no Paradigma Orientado a Notificações.
  Inscreve-se nos Fatos monitorados e avalia condição/executa ação ao receber notificações.

  Suporta dois modos:
  - Funções anônimas: start_link(fatos, condicao_fn, acao_fn)
  - Módulo (Hot Swap): start_link(fatos, modulo) usa avaliar/1 e executar/1 do módulo

  Opção `edge_triggered: true` em `start_link(fatos, modulo, edge_triggered: true)`:
  executa a ação só na transição da condição de falsa para verdadeira (evita reentradas
  enquanto a condição permanece verdadeira).

  Opção `drain_mailbox: true` (default) ou `false`, ou `Application.get_env(:tec0301_pon, :regra_drain_mailbox, true)`:
  quando `false`, não coalesce mensagens na caixa de entrada (útil para benchmarks A/B).

  Mensagens suportadas:
  - `{:notificacao, nome_fato, valor}` — drenagem de mensagens consecutivas do mesmo formato
    (e de `{:notificacoes_lote, map}`) antes de uma única avaliação reduz trabalho em *bursts*.
  - `{:notificacoes_lote, %{fato => valor, ...}}` — mescla só as chaves que a regra observa.
  """
  use GenServer

  @doc """
  Inicia uma Regra com funções anônimas (condição e ação).
  """
  def start_link(fatos_monitorados, condicao_fn, acao_fn)
      when is_list(fatos_monitorados) and is_function(condicao_fn, 1) and is_function(acao_fn, 1) do
    drain_mailbox = drain_mailbox_opt([])

    GenServer.start_link(__MODULE__, %{
      fatos: fatos_monitorados,
      memoria: %{},
      condicao: condicao_fn,
      acao: acao_fn,
      modulo: nil,
      instigation_list: [],
      edge_triggered: false,
      ultima_condicao: false,
      drain_mailbox: drain_mailbox,
      estatisticas_notificacoes: 0,
      estatisticas_execucoes: 0,
      estatisticas_drenadas: 0,
      estatisticas_avaliacoes: 0
    })
  end

  def start_link(fatos_monitorados, modulo, opts)
      when is_list(fatos_monitorados) and is_atom(modulo) and is_list(opts) do
    instigation_list = Keyword.get(opts, :instigation_list, [])
    edge_triggered = Keyword.get(opts, :edge_triggered, false)
    drain_mailbox = drain_mailbox_opt(opts)

    GenServer.start_link(__MODULE__, %{
      fatos: fatos_monitorados,
      memoria: %{},
      condicao: nil,
      acao: nil,
      modulo: modulo,
      instigation_list: instigation_list,
      edge_triggered: edge_triggered,
      ultima_condicao: false,
      drain_mailbox: drain_mailbox,
      estatisticas_notificacoes: 0,
      estatisticas_execucoes: 0,
      estatisticas_drenadas: 0,
      estatisticas_avaliacoes: 0
    })
  end

  defp drain_mailbox_opt(opts) when is_list(opts) do
    case Keyword.get(opts, :drain_mailbox) do
      nil -> Application.get_env(:tec0301_pon, :regra_drain_mailbox, true)
      v when is_boolean(v) -> v
    end
  end

  @doc """
  Inicia uma Regra com módulo (para Hot Code Swapping).
  O módulo deve exportar avaliar/1 e executar/1.
  Para lista de instigações, use `start_link(fatos, modulo, instigation_list: [...])`.
  """
  def start_link(fatos_monitorados, modulo) when is_list(fatos_monitorados) and is_atom(modulo) do
    start_link(fatos_monitorados, modulo, [])
  end

  @doc """
  Retorna um map com contagens para observabilidade e POCs.

  - **`notificacoes`**: unidades de mensagem processadas (`1 + drained` por ciclo quando o drain está ativo).
  - **`execucoes`**: ações disparadas.
  - **`drained_messages`**: mensagens extra absorvidas pelo drain do mailbox (soma dos `acc` em `drain_notificacoes`).
  - **`avaliacoes`**: chamadas a `avaliar_apos_memoria/2` (uma por ciclo de notificação recebida).

  Passar o pid da regra (retornado por start_link ou pelo módulo gerado pelo Builder).
  """
  def estatisticas(pid) when is_pid(pid) do
    GenServer.call(pid, :estatisticas)
  end

  @doc """
  Zera os contadores de notificações e execuções desta regra.
  """
  def reset_estatisticas(pid) when is_pid(pid) do
    GenServer.cast(pid, :reset_estatisticas)
  end

  @impl true
  def init(estado) do
    estado =
      estado
      |> Map.put_new(:instigation_list, [])
      |> Map.put_new(:estatisticas_notificacoes, 0)
      |> Map.put_new(:estatisticas_execucoes, 0)
      |> Map.put_new(:drain_mailbox, true)
      |> Map.put_new(:estatisticas_drenadas, 0)
      |> Map.put_new(:estatisticas_avaliacoes, 0)

    Enum.each(estado.fatos, fn fato ->
      Registry.register(Tec0301Pon.PON.PubSub, fato, [])
    end)

    memoria_inicial =
      Enum.reduce(estado.fatos, %{}, fn fato, acc ->
        valor = Tec0301Pon.PON.Fato.obter(fato)
        Map.put(acc, fato, valor)
      end)

    {:ok, %{estado | memoria: memoria_inicial}}
  end

  @impl true
  def handle_info({:notificacao, nome_fato, novo_valor}, estado) do
    base = Map.get(estado, :estatisticas_notificacoes, 0)
    nova_memoria = Map.put(estado.memoria, nome_fato, novo_valor)

    {nova_memoria, drained} =
      if Map.get(estado, :drain_mailbox, true) do
        drain_notificacoes(nova_memoria, estado, 0)
      else
        {nova_memoria, 0}
      end

    estado =
      estado
      |> Map.put(:estatisticas_notificacoes, base + 1 + drained)
      |> Map.update(:estatisticas_drenadas, drained, &(&1 + drained))

    avaliar_apos_memoria(estado, nova_memoria)
  end

  def handle_info({:notificacoes_lote, updates}, estado) when is_map(updates) do
    base = Map.get(estado, :estatisticas_notificacoes, 0)
    relevante = Map.take(updates, estado.fatos)
    nova_memoria = Map.merge(estado.memoria, relevante)

    {nova_memoria, drained} =
      if Map.get(estado, :drain_mailbox, true) do
        drain_notificacoes(nova_memoria, estado, 0)
      else
        {nova_memoria, 0}
      end

    estado =
      estado
      |> Map.put(:estatisticas_notificacoes, base + 1 + drained)
      |> Map.update(:estatisticas_drenadas, drained, &(&1 + drained))

    avaliar_apos_memoria(estado, nova_memoria)
  end

  def handle_info(_msg, estado), do: {:noreply, estado}

  @impl true
  def handle_call(:estatisticas, _from, estado) do
    result = %{
      notificacoes: Map.get(estado, :estatisticas_notificacoes, 0),
      execucoes: Map.get(estado, :estatisticas_execucoes, 0),
      drained_messages: Map.get(estado, :estatisticas_drenadas, 0),
      avaliacoes: Map.get(estado, :estatisticas_avaliacoes, 0)
    }

    {:reply, result, estado}
  end

  @impl true
  def handle_cast(:reset_estatisticas, estado) do
    novo_estado =
      estado
      |> Map.put(:estatisticas_notificacoes, 0)
      |> Map.put(:estatisticas_execucoes, 0)
      |> Map.put(:estatisticas_drenadas, 0)
      |> Map.put(:estatisticas_avaliacoes, 0)
      |> Map.put(:ultima_condicao, false)

    {:noreply, novo_estado}
  end

  defp drain_notificacoes(memoria, estado, acc) do
    receive do
      {:notificacao, nome, valor} ->
        drain_notificacoes(Map.put(memoria, nome, valor), estado, acc + 1)

      {:notificacoes_lote, upd} when is_map(upd) ->
        rel = Map.take(upd, estado.fatos)
        drain_notificacoes(Map.merge(memoria, rel), estado, acc + 1)
    after
      0 ->
        {memoria, acc}
    end
  end

  defp avaliar_apos_memoria(estado, nova_memoria) do
    estado = Map.update(estado, :estatisticas_avaliacoes, 1, &(&1 + 1))
    disparado = avaliar_condicao(estado, nova_memoria)
    ultima = Map.get(estado, :ultima_condicao, false)

    executar? =
      if Map.get(estado, :edge_triggered, false) do
        disparado and not ultima
      else
        disparado
      end

    estado =
      if executar? do
        estado
        |> Map.update(:estatisticas_execucoes, 1, &(&1 + 1))
        |> then(fn s ->
          executar_acao(s, nova_memoria)
          run_instigations(s)
          s
        end)
      else
        estado
      end

    {:noreply,
     estado
     |> Map.put(:memoria, nova_memoria)
     |> Map.put(:ultima_condicao, disparado)}
  end

  defp run_instigations(%{instigation_list: list}) when is_list(list) do
    for {mod, fun, args} <- list do
      Task.start(mod, fun, args)
    end
  end

  defp avaliar_condicao(%{modulo: nil, condicao: fn_cond}, memoria), do: fn_cond.(memoria)

  defp avaliar_condicao(%{modulo: mod}, memoria) when is_atom(mod),
    do: apply(mod, :avaliar, [memoria])

  defp executar_acao(%{modulo: nil, acao: fn_acao}, memoria), do: fn_acao.(memoria)

  defp executar_acao(%{modulo: mod}, memoria) when is_atom(mod),
    do: apply(mod, :executar, [memoria])

  @impl true
  def code_change(_old_vsn, estado, _extra) do
    {:ok, estado}
  end
end
