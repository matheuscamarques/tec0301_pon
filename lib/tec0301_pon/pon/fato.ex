defmodule Tec0301Pon.PON.Fato do
  @moduledoc """
  GenServer que representa um Fato no Paradigma Orientado a Notificações.
  Armazena um valor e notifica todos os inscritos no Registry quando o valor é atualizado.

  ## Comportamento

  - **`atualizar/2`**: se o novo valor for **igual** ao atual (`===`), não incrementa
    `estatisticas` e **não** dispara `Registry.dispatch` (reduz message storm).
  - **`estatisticas`**: conta apenas **dispatches** efetivos (transições de valor que
    notificaram inscritos), não tentativas redundantes.
  - **`obter/1`**: leitura via ETS quando disponível; fallback a `GenServer.call` se a
    entrada ainda não existir (ex.: corrida no arranque).
  - **ETS**: tabela nomeada com `read_concurrency` e `write_concurrency` (artigo 20) para
    leituras concorrentes e escritas paralelas por vários processos `Fato`.
  """

  use GenServer

  @ets_table :tec0301_pon_fato_values

  @doc """
  Garante que a tabela ETS nomeada existe. Invocado na subida da aplicação `tec0301_pon`.
  """
  def ensure_ets! do
    case :ets.whereis(@ets_table) do
      :undefined ->
        :ets.new(@ets_table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        :ok
    end

    :ok
  end

  @doc false
  def ets_table_name, do: @ets_table

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
  Atualiza o valor do fato. Dispara notificação assíncrona para todas as Regras inscritas
  apenas quando o valor muda.
  """
  def atualizar(nome_do_fato, novo_valor) when is_atom(nome_do_fato) do
    GenServer.cast(nome_do_fato, {:atualizar, novo_valor})
  end

  @doc """
  Atualiza vários fatos com **coalescência**: uma mensagem `{:notificacoes_lote, mapa}` por
  inscrito, contendo só fatos cujo valor mudou (ver `Tec0301Pon.PON.Fanout`).
  """
  def atualizar_lote(updates) when is_map(updates) do
    Tec0301Pon.PON.Fanout.atualizar_lote(updates)
  end

  @doc """
  Retorna o valor atual do fato (para preencher memória inicial das Regras).
  Preferência por ETS; evite `GenServer.call` repetido em laços muito apertados quando possível.
  """
  def obter(nome_do_fato) when is_atom(nome_do_fato) do
    case :ets.lookup(@ets_table, nome_do_fato) do
      [{^nome_do_fato, valor}] -> valor
      [] -> GenServer.call(nome_do_fato, :obter)
    end
  end

  @doc """
  Retorna o número de **notificações disparadas** (dispatches ao Registry) desde o início
  ou último reset — não inclui atualizações silenciosas nem `atualizar` sem mudança de valor.
  """
  def estatisticas(nome_do_fato) when is_atom(nome_do_fato) do
    GenServer.call(nome_do_fato, :estatisticas)
  end

  @doc """
  Zera o contador de atualizações deste fato.
  """
  def reset_estatisticas(nome_do_fato) when is_atom(nome_do_fato) do
    GenServer.cast(nome_do_fato, :reset_estatisticas)
  end

  @impl true
  def init(estado) do
    estado = Map.put_new(estado, :estatisticas, 0)
    ets_put(estado.nome, estado.valor)
    {:ok, estado}
  end

  @impl true
  def handle_call(:obter, _from, estado) do
    {:reply, estado.valor, estado}
  end

  def handle_call(:estatisticas, _from, estado) do
    count = Map.get(estado, :estatisticas, 0)
    {:reply, count, estado}
  end

  def handle_call({:atualizar_sem_dispatch, novo_valor}, _from, estado) do
    if valor_igual?(estado.valor, novo_valor) do
      {:reply, :unchanged, estado}
    else
      novo_estado = %{estado | valor: novo_valor}
      ets_put(estado.nome, novo_valor)
      {:reply, :changed, novo_estado}
    end
  end

  @impl true
  def handle_cast({:atualizar, novo_valor}, estado) do
    if valor_igual?(estado.valor, novo_valor) do
      {:noreply, estado}
    else
      novo_estado =
        estado
        |> Map.update(:estatisticas, 1, &(&1 + 1))
        |> Map.put(:valor, novo_valor)

      ets_put(estado.nome, novo_valor)

      Registry.dispatch(Tec0301Pon.PON.PubSub, estado.nome, fn inscritos ->
        for {pid, _} <- inscritos, do: send(pid, {:notificacao, estado.nome, novo_valor})
      end)

      {:noreply, novo_estado}
    end
  end

  def handle_cast(:reset_estatisticas, estado) do
    novo_estado = %{estado | estatisticas: 0}
    {:noreply, novo_estado}
  end

  @impl true
  def code_change(_old_vsn, estado, _extra) do
    {:ok, estado}
  end

  defp valor_igual?(a, b), do: a === b

  defp ets_put(nome, valor) do
    try do
      :ets.insert(@ets_table, {nome, valor})
    rescue
      ArgumentError -> :ok
    end
  end
end
