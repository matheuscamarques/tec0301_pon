defmodule Tec0301Pon.PON.Builder do
  @moduledoc """
  DSL PON: regras, premissas, condições agregadoras e opcionalmente condição por string.

  - **defrule** – regra com `watch:`, `when:` (AST ou string) e `do:` (bloco ou `instigations: [...]`).
  - Opcional: **`edge_triggered: true`** — só executa a ação na transição falso→verdadeiro da condição (ver `Tec0301Pon.PON.Regra`).
  - **defpremissa** – premissa reutilizável: observa fatos, avalia condição e atualiza um fato derivado quando o booleano muda.
  - **defcondicao** – condição de primeira classe: agrega vários fatos (em geral booleans de premissas) com `merge: :all | :any` ou `when:` customizado.
  - Regras, premissas e condições geram submódulos com `start_link/0`; use-os no bootstrap do seu grafo PON.
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
  defmacro defrule(nome_da_regra, watch: fatos, when: condicao, do: acao)
           when is_binary(condicao) do
    build_defrule_string(nome_da_regra, fatos, condicao, acao, __CALLER__, false)
  end

  defmacro defrule(nome_da_regra, watch: fatos, when: condicao, edge_triggered: edge?, do: acao)
           when is_binary(condicao) do
    build_defrule_string(nome_da_regra, fatos, condicao, acao, __CALLER__, edge?)
  end

  defmacro defrule(nome_da_regra, watch: fatos, when: condicao, do: acao) do
    build_defrule_ast(nome_da_regra, fatos, condicao, acao, __CALLER__, false)
  end

  defmacro defrule(nome_da_regra, watch: fatos, when: condicao, edge_triggered: edge?, do: acao) do
    build_defrule_ast(nome_da_regra, fatos, condicao, acao, __CALLER__, edge?)
  end

  defp build_defrule_ast(nome_da_regra, fatos, condicao, acao, caller, edge_triggered?) do
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
              _ = var!(memoria)

              for {mod, fun, args} <- unquote(instigation_list), do: Task.start(mod, fun, args)
            end

          sl =
            quote do
              Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__,
                instigation_list: unquote(instigation_list),
                edge_triggered: unquote(edge_triggered?)
              )
            end

          {ex, sl}

        _ ->
          ex =
            quote do
              var!(memoria)
              unquote(acao)
            end

          sl =
            quote do
              Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__,
                edge_triggered: unquote(edge_triggered?)
              )
            end

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

  @doc """
  Define uma Condição PON (agregador lógico sobre fatos, em geral booleans de premissas).

  Use `merge: :all` para AND (todos os valores observados devem ser estritamente `true`)
  ou `merge: :any` para OR. Alternativa: `when:` com expressão sobre `memoria` (mapa fato => valor).

  Exemplo:

      defcondicao AlarmeHabilitado,
        watch: [:temp_alta, :umidade_baixa],
        merge: :all,
        derive: :cond_alarme,
        criar_fato: true

      defrule DispararAlarme,
        watch: [:cond_alarme],
        when: memoria[:cond_alarme] == true,
        do: ...

  Opções obrigatórias: `watch:`, `derive:` e **uma** de `merge:` ou `when:`.
  Opcional: `criar_fato: true` — cria o fato derivado com `false` se não existir.
  """
  defmacro defcondicao(nome_condicao, opts) when is_list(opts) do
    fatos = Keyword.fetch!(opts, :watch)
    derive = Keyword.fetch!(opts, :derive)
    criar = Keyword.get(opts, :criar_fato, false)

    cond do
      Keyword.has_key?(opts, :when) and Keyword.has_key?(opts, :merge) ->
        raise ArgumentError, "defcondicao: use either :merge or :when, not both"

      Keyword.has_key?(opts, :when) ->
        expr = Keyword.fetch!(opts, :when)
        build_defcondicao_when(nome_condicao, fatos, derive, expr, criar, __CALLER__)

      Keyword.has_key?(opts, :merge) ->
        merge = Keyword.fetch!(opts, :merge)
        build_defcondicao_merge(nome_condicao, fatos, derive, merge, criar, __CALLER__)

      true ->
        raise ArgumentError, "defcondicao requires :merge (:all | :any) or :when:"
    end
  end

  defp build_defcondicao_merge(nome_condicao, fatos, derive, merge, criar, caller) do
    unless merge in [:all, :any] do
      raise ArgumentError, "defcondicao :merge must be :all or :any, got: #{inspect(merge)}"
    end

    name_atoms =
      case nome_condicao do
        {:__aliases__, _, parts} -> parts
        other when is_atom(other) -> [other]
      end

    modulo = Module.concat([caller.module | name_atoms])

    quote do
      defmodule unquote(modulo) do
        @moduledoc false

        def start_link do
          Tec0301Pon.PON.Condicao.start_link(
            unquote(derive),
            unquote(fatos),
            merge: unquote(merge),
            criar_fato_derivado: unquote(criar)
          )
        end
      end
    end
  end

  defp build_defcondicao_when(nome_condicao, fatos, derive, expr, criar, caller) do
    name_atoms =
      case nome_condicao do
        {:__aliases__, _, parts} -> parts
        other when is_atom(other) -> [other]
      end

    modulo = Module.concat([caller.module | name_atoms])

    quote do
      defmodule unquote(modulo) do
        @moduledoc false

        def combine(var!(memoria)), do: unquote(expr)

        def start_link do
          Tec0301Pon.PON.Condicao.start_link(
            unquote(derive),
            unquote(fatos),
            combine_fn: &combine/1,
            criar_fato_derivado: unquote(criar)
          )
        end
      end
    end
  end

  defp build_defrule_string(nome_da_regra, fatos, expr_string, acao, caller, edge_triggered?) do
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
              _ = memoria

              for {mod, fun, args} <- unquote(instigation_list), do: Task.start(mod, fun, args)
            end

          sl =
            quote do
              Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__,
                instigation_list: unquote(instigation_list),
                edge_triggered: unquote(edge_triggered?)
              )
            end

          {ex, sl}

        _ ->
          ex =
            quote do
              _ = memoria
              unquote(acao)
            end

          sl =
            quote do
              Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__,
                edge_triggered: unquote(edge_triggered?)
              )
            end

          {ex, sl}
      end

    quote do
      defmodule unquote(modulo) do
        @moduledoc false

        def avaliar(memoria) do
          {result, _} = Code.eval_string(unquote(expr_string), memoria: memoria)
          result
        end

        def executar(memoria), do: unquote(executar_impl)
        def start_link, do: unquote(start_link_impl)
      end
    end
  end
end
