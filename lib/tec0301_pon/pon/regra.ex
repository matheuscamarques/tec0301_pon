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
      modulo: nil
    })
  end

  @doc """
  Inicia uma Regra com módulo (para Hot Code Swapping).
  O módulo deve exportar avaliar/1 e executar/1.
  """
  def start_link(fatos_monitorados, modulo) when is_list(fatos_monitorados) and is_atom(modulo) do
    GenServer.start_link(__MODULE__, %{
      fatos: fatos_monitorados,
      memoria: %{},
      condicao: nil,
      acao: nil,
      modulo: modulo
    })
  end

  @impl true
  def init(estado) do
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
    nova_memoria = Map.put(estado.memoria, nome_fato, novo_valor)
    disparado = avaliar_condicao(estado, nova_memoria)
    if disparado, do: executar_acao(estado, nova_memoria)
    {:noreply, %{estado | memoria: nova_memoria}}
  end

  def handle_info(_msg, estado), do: {:noreply, estado}

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
