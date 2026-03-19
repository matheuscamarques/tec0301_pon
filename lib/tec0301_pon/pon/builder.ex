defmodule Tec0301Pon.PON.Builder do
  @moduledoc """
  DSL PON: regras, premissas e opcionalmente condição por string.

  - **defrule** – regra com `watch:`, `when:` (AST ou string) e `do:` (bloco ou `instigations: [...]`).
  - **defpremissa** – premissa reutilizável: observa fatos, avalia condição e atualiza um fato derivado quando o booleano muda.
  - Regras e premissas geram submódulos com `start_link/0`; use-os no bootstrap do seu grafo PON.
  """
  defmacro __using__(_opts) do
    quote do
      import Tec0301Pon.PON.Builder
    end
  end

  @doc """
  Define uma regra PON como submódulo com avaliar/1 e executar/1.

  - `when:` pode ser expressão em código (AST) ou string (avaliada com Code.eval_string; uso interno/config).
  - `do:` pode ser um bloco de código ou `instigations: [{Module, :fun, [args]}, ...]` para disparar Tasks ao disparar a regra.

  Exemplo:

      defrule RegraIrrigacao,
        watch: [:temp_ambiente, :umidade_solo, :estado_bomba, :nivel_tanque],
        when: memoria[:temp_ambiente] > 30 and memoria[:umidade_solo] < 40,
        do: (
          Adapters.BombaDeAgua.ligar()
          Tec0301Pon.PON.Fato.atualizar(:estado_bomba, :ligada)
        )

  Inicie com ModuloGerado.start_link/0.
  """
  # Quando when: é string, usa avaliação por Code.eval_string
  defmacro defrule(nome_da_regra, watch: fatos, when: condicao, do: acao) when is_binary(condicao) do
    build_defrule_string(nome_da_regra, fatos, condicao, acao, __CALLER__)
  end

  defmacro defrule(nome_da_regra, watch: fatos, when: condicao, do: acao) do
    build_defrule_ast(nome_da_regra, fatos, condicao, acao, __CALLER__)
  end

  defp build_defrule_ast(nome_da_regra, fatos, condicao, acao, caller) do
    name_atoms =
      case nome_da_regra do
        {:__aliases__, _, parts} -> parts
        other when is_atom(other) -> [other]
      end

    modulo = Module.concat([caller.module | name_atoms])

    {executar_impl, start_link_impl} =
      case acao do
        [instigations: instigation_list] ->
          ex =
            quote do
              for {mod, fun, args} <- unquote(instigation_list), do: Task.start(mod, fun, args)
            end
          sl =
            quote do
              Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__, instigation_list: unquote(instigation_list))
            end
          {ex, sl}

        _ ->
          ex =
            quote do
              var!(memoria)
              unquote(acao)
            end
          sl = quote(do: Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__))
          {ex, sl}
      end

    quote do
      defmodule unquote(modulo) do
        @moduledoc false

        def avaliar(var!(memoria)), do: unquote(condicao)
        def executar(var!(memoria)), do: unquote(executar_impl)
        def start_link, do: unquote(start_link_impl)
      end
    end
  end

  @doc """
  Define uma premissa reutilizável (estilo NOP): observa 1 ou 2 fatos, avalia a condição
  e atualiza o fato derivado **apenas quando o resultado booleano muda**. Várias regras
  podem observar o fato derivado sem duplicar a condição.

  Exemplo:

      defpremissa TempAlta,
        watch: [:temp_ambiente],
        when: (memoria[:temp_ambiente] || 0) > 30,
        derive: :temp_alta,
        criar_fato: true

  Depois, regras podem usar `watch: [:temp_alta, ...]` em vez de repetir a condição.

  Opções obrigatórias: `watch:`, `when:`, `derive:` (nome do fato derivado).
  Opcional: `criar_fato: true` – cria o fato derivado com false se não existir.
  """
  defmacro defpremissa(nome_premissa, opts) when is_list(opts) do
    fatos_fonte = Keyword.fetch!(opts, :watch)
    condicao = Keyword.fetch!(opts, :when)
    fato_derivado = Keyword.fetch!(opts, :derive)
    criar = Keyword.get(opts, :criar_fato, false)
    build_defpremissa(nome_premissa, fatos_fonte, condicao, fato_derivado, criar, __CALLER__)
  end

  defp build_defpremissa(nome_premissa, fatos_fonte, condicao, fato_derivado, criar, caller) do
    name_atoms =
      case nome_premissa do
        {:__aliases__, _, parts} -> parts
        other when is_atom(other) -> [other]
      end

    modulo = Module.concat([caller.module | name_atoms])

    quote do
      defmodule unquote(modulo) do
        @moduledoc false

        def condicao(var!(memoria)), do: unquote(condicao)

        def start_link do
          Tec0301Pon.PON.Premissa.start_link(
            unquote(fato_derivado),
            unquote(fatos_fonte),
            &condicao/1,
            criar_fato_derivado: unquote(criar)
          )
        end
      end
    end
  end

  defp build_defrule_string(nome_da_regra, fatos, expr_string, acao, caller) do
    name_atoms =
      case nome_da_regra do
        {:__aliases__, _, parts} -> parts
        other when is_atom(other) -> [other]
      end

    modulo = Module.concat([caller.module | name_atoms])

    {executar_impl, start_link_impl} =
      case acao do
        [instigations: instigation_list] ->
          ex = quote do
            for {mod, fun, args} <- unquote(instigation_list), do: Task.start(mod, fun, args)
          end
          sl = quote do
            Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__, instigation_list: unquote(instigation_list))
          end
          {ex, sl}

        _ ->
          ex = quote do
            memoria
            unquote(acao)
          end
          sl = quote(do: Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__))
          {ex, sl}
      end

    quote do
      defmodule unquote(modulo) do
        @moduledoc false

        def avaliar(memoria) do
          {result, _} = Code.eval_string(unquote(expr_string), [memoria: memoria])
          result
        end

        def executar(memoria), do: unquote(executar_impl)
        def start_link, do: unquote(start_link_impl)
      end
    end
  end
end
