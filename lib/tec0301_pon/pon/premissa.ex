defmodule Tec0301Pon.PON.Premissa do
  @moduledoc """
  Processo que observa 1 ou 2 fatos, avalia uma condição e atualiza um fato derivado
  apenas quando o resultado booleano **muda**. Permite reutilizar a mesma premissa
  em várias regras (estilo NOP.Element.Premise) sem duplicar lógica.

  Para combinar várias saídas booleanas (AND/OR), use `Tec0301Pon.PON.Condicao` ou o macro
  `defcondicao` em `Tec0301Pon.PON.Builder`.

  Usa o mesmo barramento Registry que Fato/Regra; não adiciona links no Fato.
  O fato derivado deve existir antes (ou será criado com valor inicial false se
  `criar_fato_derivado: true` em opts).
  """
  use GenServer

  @doc """
  Inicia uma Premissa que observa os fatos em `fatos_fonte`, avalia `condicao_fn(memoria)`
  e, quando o resultado booleano muda, atualiza o fato `nome_fato_derivado`.

  - `nome_fato_derivado`: atom, nome do fato que armazenará true/false.
  - `fatos_fonte`: lista de 1 ou 2 atoms (nomes de fatos).
  - `condicao_fn`: função `fn memoria -> boolean end`, onde memoria é um map fato => valor.

  Opções:
  - `:criar_fato_derivado` – se true, a Premissa inicia o fato derivado com valor false
    quando ele não existir (default: false; o fato deve já existir).
  """
  def start_link(nome_fato_derivado, fatos_fonte, condicao_fn, opts \\ [])
      when is_atom(nome_fato_derivado) and is_list(fatos_fonte) and is_function(condicao_fn, 1) do
    criar = Keyword.get(opts, :criar_fato_derivado, false)

    state = %{
      nome_fato_derivado: nome_fato_derivado,
      fatos_fonte: fatos_fonte,
      condicao_fn: condicao_fn,
      memoria: %{},
      resultado_anterior: nil,
      criar_fato_derivado: criar
    }

    GenServer.start_link(__MODULE__, state)
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

    resultado = estado.condicao_fn.(memoria_inicial)
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
    novo_resultado = estado.condicao_fn.(nova_memoria)

    if novo_resultado != estado.resultado_anterior do
      Tec0301Pon.PON.Fato.atualizar(estado.nome_fato_derivado, novo_resultado)
    end

    {:noreply, %{estado | memoria: nova_memoria, resultado_anterior: novo_resultado}}
  end

  def handle_info(_msg, estado), do: {:noreply, estado}
end
