defmodule Tec0301Pon.PON.Service do
  @moduledoc """
  Serviço opcional para agregação de estatísticas e controle global do grafo PON.

  Não é iniciado automaticamente pelo Application. Quem quiser usar deve:
  1. Iniciar o Service: `Tec0301Pon.PON.Service.start_link/0` (e.g. sob um supervisor).
  2. Registrar fatos e regras após criá-los: `registrar_fato/2`, `registrar_regra/2`.

  Inspirado no NOP.Service (listas de elementos, get_statistics_count, reset_statistics).
  """
  use GenServer

  @doc """
  Inicia o serviço PON (opcional). Use apenas se for usar estatísticas globais ou wait_until_queues_empty.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{fatos: [], regras: []}, name: name)
  end

  @doc """
  Registra um fato no serviço. `nome` é o atom do fato, `pid` o processo (use o nome como processo registrado, não há pid para Fato).
  Para Fato o processo é registrado pelo nome; passamos o nome e fazemos call ao nome.
  """
  def registrar_fato(nome, _pid_or_nome) when is_atom(nome) do
    GenServer.cast(__MODULE__, {:registrar_fato, nome, nome})
  end

  @doc """
  Registra uma regra no serviço. `id` pode ser qualquer termo (ex.: atom com nome da regra), `pid` o pid da regra.
  """
  def registrar_regra(id, pid) when is_pid(pid) do
    GenServer.cast(__MODULE__, {:registrar_regra, id, pid})
  end

  @doc """
  Retorna a soma das estatísticas de todos os fatos e regras registrados.
  Fatos: contagem de atualizações. Regras: map com notificacoes e execucoes.
  """
  def estatisticas_globais do
    GenServer.call(__MODULE__, :estatisticas_globais)
  end

  @doc """
  Zera os contadores de todos os fatos e regras registrados.
  """
  def reset_estatisticas do
    GenServer.cast(__MODULE__, :reset_estatisticas)
  end

  @doc """
  Bloqueia até que todas as filas de mensagens dos processos registrados estejam vazias,
  ou até o timeout (em ms). Útil em testes. Retorna :ok ou :timeout.
  """
  def wait_until_queues_empty(timeout_ms) when is_integer(timeout_ms) and timeout_ms >= 0 do
    GenServer.call(__MODULE__, {:wait_until_queues_empty, timeout_ms})
  end

  @impl true
  def init(estado) do
    {:ok, estado}
  end

  @impl true
  def handle_cast({:registrar_fato, nome, key}, estado) do
    fatos = [{nome, key} | estado.fatos]
    {:noreply, %{estado | fatos: fatos}}
  end

  def handle_cast({:registrar_regra, id, pid}, estado) do
    regras = [{id, pid} | estado.regras]
    {:noreply, %{estado | regras: regras}}
  end

  def handle_cast(:reset_estatisticas, estado) do
    for {_nome, key} <- estado.fatos do
      Tec0301Pon.PON.Fato.reset_estatisticas(key)
    end

    for {_id, pid} <- estado.regras do
      Tec0301Pon.PON.Regra.reset_estatisticas(pid)
    end

    {:noreply, estado}
  end

  @impl true
  def handle_call(:estatisticas_globais, _from, estado) do
    fatos_count =
      Enum.reduce(estado.fatos, 0, fn {_nome, key}, acc ->
        acc + Tec0301Pon.PON.Fato.estatisticas(key)
      end)

    regras_count =
      Enum.reduce(estado.regras, %{notificacoes: 0, execucoes: 0}, fn {_id, pid}, acc ->
        s = Tec0301Pon.PON.Regra.estatisticas(pid)

        %{
          notificacoes: acc.notificacoes + s.notificacoes,
          execucoes: acc.execucoes + s.execucoes
        }
      end)

    result = %{
      fatos: fatos_count,
      regras: regras_count
    }

    {:reply, result, estado}
  end

  @impl true
  def handle_call({:wait_until_queues_empty, timeout_ms}, from, estado) do
    pids = Enum.map(estado.regras, fn {_id, pid} -> pid end)
    server = self()

    spawn(fn ->
      deadline = System.monotonic_time(:millisecond) + timeout_ms
      result = wait_loop(pids, deadline)
      send(server, {:wait_done, from, result})
    end)

    {:noreply, estado}
  end

  @impl true
  def handle_info({:wait_done, from, result}, estado) do
    GenServer.reply(from, result)
    {:noreply, estado}
  end

  defp wait_loop(pids, deadline) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      :timeout
    else
      busy =
        Enum.any?(pids, fn pid ->
          case Process.info(pid, :message_queue_len) do
            {:message_queue_len, len} -> len > 0
            _ -> false
          end
        end)

      if busy do
        Process.sleep(10)
        wait_loop(pids, deadline)
      else
        :ok
      end
    end
  end
end
