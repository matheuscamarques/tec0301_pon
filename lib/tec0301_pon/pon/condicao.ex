defmodule Tec0301Pon.PON.Condicao do
  @moduledoc """
  Agrega o resultado booleano de vários fatos (tipicamente saídas de `Premissa`) com
  **AND** (`:merge :all`) ou **OR** (`:merge :any`), ou com função customizada — e
  materializa o resultado num fato derivado **somente quando o booleano agregado muda**.

  Complementa `Tec0301Pon.PON.Premissa`: várias premissas alimentam uma condição de regra;
  a `Regra` pode então observar só o fato derivado da condição (e opcionalmente outros fatos).
  """
  use GenServer

  @doc """
  Inicia uma Condição que observa `fatos_fonte`, combina com `:merge` ou `:combine_fn`,
  e atualiza `nome_fato_derivado` quando o resultado booleano muda.

  Opções (uma das duas formas de combinação):

  - `:merge` — `:all` (todos `=== true`) ou `:any` (pelo menos um `=== true`)
  - `:combine_fn` — `fn memoria -> boolean end` sobre o mapa `fato => valor`

  Outras:

  - `:criar_fato_derivado` — se true, cria o fato derivado com `false` quando ausente
  """
  def start_link(nome_fato_derivado, fatos_fonte, opts \\ [])
      when is_atom(nome_fato_derivado) and is_list(fatos_fonte) and is_list(opts) do
    combine_fn = resolve_combine_fn(fatos_fonte, opts)
    criar = Keyword.get(opts, :criar_fato_derivado, false)

    state = %{
      nome_fato_derivado: nome_fato_derivado,
      fatos_fonte: fatos_fonte,
      combine_fn: combine_fn,
      memoria: %{},
      resultado_anterior: nil,
      criar_fato_derivado: criar
    }

    GenServer.start_link(__MODULE__, state)
  end

  defp resolve_combine_fn(fatos_fonte, opts) do
    cf = Keyword.get(opts, :combine_fn)
    merge = Keyword.get(opts, :merge)

    case {cf, merge} do
      {f, nil} when is_function(f, 1) ->
        f

      {nil, :all} ->
        fn m -> Enum.all?(fatos_fonte, &(Map.get(m, &1) === true)) end

      {nil, :any} ->
        fn m -> Enum.any?(fatos_fonte, &(Map.get(m, &1) === true)) end

      {nil, nil} ->
        raise ArgumentError,
              "Condicao.start_link/3 requires :merge (:all | :any) or :combine_fn (fn memoria -> boolean end)"

      _ ->
        raise ArgumentError, "use either :combine_fn or :merge, not both"
    end
  end

  @impl true
  def init(estado) do
    if estado.criar_fato_derivado do
      case Process.whereis(estado.nome_fato_derivado) do
        nil ->
          {:ok, _} = Tec0301Pon.PON.Fato.start_link(estado.nome_fato_derivado, false)

        _ ->
          :ok
      end
    end

    Enum.each(estado.fatos_fonte, fn fato ->
      Registry.register(Tec0301Pon.PON.PubSub, fato, [])
    end)

    memoria_inicial =
      Enum.reduce(estado.fatos_fonte, %{}, fn fato, acc ->
        valor = Tec0301Pon.PON.Fato.obter(fato)
        Map.put(acc, fato, valor)
      end)

    resultado = estado.combine_fn.(memoria_inicial)
    Tec0301Pon.PON.Fato.atualizar(estado.nome_fato_derivado, resultado)

    {:ok,
     %{
       estado
       | memoria: memoria_inicial,
         resultado_anterior: resultado
     }}
  end

  @impl true
  def handle_info({:notificacao, nome_fato, novo_valor}, estado) do
    nova_memoria = Map.put(estado.memoria, nome_fato, novo_valor)
    {nova_memoria, _} = drain_notificacoes(nova_memoria, estado, 0)
    {:noreply, aplicar_combinacao(estado, nova_memoria)}
  end

  def handle_info({:notificacoes_lote, updates}, estado) when is_map(updates) do
    relevante = Map.take(updates, estado.fatos_fonte)
    nova_memoria = Map.merge(estado.memoria, relevante)
    {nova_memoria, _} = drain_notificacoes(nova_memoria, estado, 0)
    {:noreply, aplicar_combinacao(estado, nova_memoria)}
  end

  def handle_info(_msg, estado), do: {:noreply, estado}

  defp drain_notificacoes(memoria, estado, acc) do
    receive do
      {:notificacao, nome, valor} ->
        drain_notificacoes(Map.put(memoria, nome, valor), estado, acc + 1)

      {:notificacoes_lote, upd} when is_map(upd) ->
        rel = Map.take(upd, estado.fatos_fonte)
        drain_notificacoes(Map.merge(memoria, rel), estado, acc + 1)
    after
      0 ->
        {memoria, acc}
    end
  end

  defp aplicar_combinacao(estado, nova_memoria) do
    novo_resultado = estado.combine_fn.(nova_memoria)

    if novo_resultado != estado.resultado_anterior do
      Tec0301Pon.PON.Fato.atualizar(estado.nome_fato_derivado, novo_resultado)
    end

    %{estado | memoria: nova_memoria, resultado_anterior: novo_resultado}
  end

  @impl true
  def code_change(_old_vsn, estado, _extra) do
    {:ok, estado}
  end
end
