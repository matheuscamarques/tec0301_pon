defmodule Tec0301Pon.PON.Fato do
  @moduledoc """
  GenServer que representa um Fato no Paradigma Orientado a Notificações.
  Armazena um valor e notifica todos os inscritos no Registry quando o valor é atualizado.
  """
  use GenServer

  @doc """
  Inicia um processo Fato com nome e valor inicial.

  O nome é usado como tópico no barramento PubSub e como nome do processo.
  """
  def start_link(nome_do_fato, valor_inicial) when is_atom(nome_do_fato) do
    GenServer.start_link(__MODULE__, %{nome: nome_do_fato, valor: valor_inicial},
      name: nome_do_fato
    )
  end

  @doc """
  Atualiza o valor do fato. Dispara notificação assíncrona para todas as Regras inscritas.
  """
  def atualizar(nome_do_fato, novo_valor) when is_atom(nome_do_fato) do
    GenServer.cast(nome_do_fato, {:atualizar, novo_valor})
  end

  @doc """
  Retorna o valor atual do fato (para preencher memória inicial das Regras).
  Síncrono mas O(1); evite chamar em loops de alta frequência (artigo 06: preferir cast no hot path).
  """
  def obter(nome_do_fato) when is_atom(nome_do_fato) do
    GenServer.call(nome_do_fato, :obter)
  end

  @impl true
  def init(estado) do
    {:ok, estado}
  end

  @impl true
  def handle_call(:obter, _from, estado) do
    {:reply, estado.valor, estado}
  end

  @impl true
  def handle_cast({:atualizar, novo_valor}, estado) do
    novo_estado = %{estado | valor: novo_valor}

    Registry.dispatch(Tec0301Pon.PON.PubSub, estado.nome, fn inscritos ->
      for {pid, _} <- inscritos, do: send(pid, {:notificacao, estado.nome, novo_valor})
    end)

    {:noreply, novo_estado}
  end

  @impl true
  def code_change(_old_vsn, estado, _extra) do
    {:ok, estado}
  end
end
