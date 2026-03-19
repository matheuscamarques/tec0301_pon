defmodule Tec0301Pon.PON.Regra do
  @moduledoc """
  GenServer que representa uma Regra no Paradigma Orientado a Notificações.
  Inscreve-se nos Fatos monitorados e avalia condição/executa ação ao receber notificações.

  Suporta dois modos:
  - Funções anônimas: start_link(fatos, condicao_fn, acao_fn)
  - Módulo (Hot Swap): start_link(fatos, modulo) usa avaliar/1 e executar/1 do módulo
  """
  use GenServer

  @doc """
  Inicia uma Regra com funções anônimas (condição e ação).
  """
  def start_link(fatos_monitorados, condicao_fn, acao_fn)
      when is_list(fatos_monitorados) and is_function(condicao_fn, 1) and is_function(acao_fn, 1) do
    GenServer.start_link(__MODULE__, %{
      fatos: fatos_monitorados,
      memoria: %{},
      condicao: condicao_fn,
      acao: acao_fn,
      modulo: nil,
      instigation_list: [],
      estatisticas_notificacoes: 0,
      estatisticas_execucoes: 0
    })
  end

  def start_link(fatos_monitorados, modulo, opts)
      when is_list(fatos_monitorados) and is_atom(modulo) and is_list(opts) do
    instigation_list = Keyword.get(opts, :instigation_list, [])
    GenServer.start_link(__MODULE__, %{
      fatos: fatos_monitorados,
      memoria: %{},
      condicao: nil,
      acao: nil,
      modulo: modulo,
      instigation_list: instigation_list,
      estatisticas_notificacoes: 0,
      estatisticas_execucoes: 0
    })
  end

  @doc """
  Inicia uma Regra com módulo (para Hot Code Swapping).
  O módulo deve exportar avaliar/1 e executar/1.
  Para lista de instigações, use `start_link(fatos, modulo, instigation_list: [...])`.
  """
  def start_link(fatos_monitorados, modulo) when is_list(fatos_monitorados) and is_atom(modulo) do
    GenServer.start_link(__MODULE__, %{
      fatos: fatos_monitorados,
      memoria: %{},
      condicao: nil,
      acao: nil,
      modulo: modulo,
      instigation_list: [],
      estatisticas_notificacoes: 0,
      estatisticas_execucoes: 0
    })
  end

  @doc """
  Retorna um map com contagem de notificações recebidas e de execuções (ações disparadas).
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
    estado = Map.update(estado, :estatisticas_notificacoes, 1, &(&1 + 1))
    nova_memoria = Map.put(estado.memoria, nome_fato, novo_valor)
    disparado = avaliar_condicao(estado, nova_memoria)

    estado =
      if disparado do
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

    {:noreply, %{estado | memoria: nova_memoria}}
  end

  def handle_info(_msg, estado), do: {:noreply, estado}

  @impl true
  def handle_call(:estatisticas, _from, estado) do
    result = %{
      notificacoes: Map.get(estado, :estatisticas_notificacoes, 0),
      execucoes: Map.get(estado, :estatisticas_execucoes, 0)
    }
    {:reply, result, estado}
  end

  @impl true
  def handle_cast(:reset_estatisticas, estado) do
    novo_estado =
      estado
      |> Map.put(:estatisticas_notificacoes, 0)
      |> Map.put(:estatisticas_execucoes, 0)
    {:noreply, novo_estado}
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
