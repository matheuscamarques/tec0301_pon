defmodule Tec0301Pon.PON.Builder do
  @moduledoc """
  DSL para definir Regras PON via metaprogramação.
  Gera módulos com avaliar/1 e executar/1 (funções nomeadas) para suporte a Hot Code Swapping.
  """
  defmacro __using__(_opts) do
    quote do
      import Tec0301Pon.PON.Builder
    end
  end

  @doc """
  Define uma regra PON como submódulo com avaliar/1 e executar/1.

  Uso (memoria é um map; use memoria[:fato] na condição e no bloco):

      defrule RegraIrrigacao,
        watch: [:temp_ambiente, :umidade_solo, :estado_bomba, :nivel_tanque],
        when: memoria[:temp_ambiente] > 30 and memoria[:umidade_solo] < 40 and memoria[:estado_bomba] == :desligada and memoria[:nivel_tanque] >= 10,
        do: (
          Adapters.BombaDeAgua.ligar()
          Tec0301Pon.PON.Fato.atualizar(:estado_bomba, :ligada)
        )

  Inicie com ModuloGerado.start_link/0.
  """
  defmacro defrule(nome_da_regra, watch: fatos, when: condicao, do: acao) do
    name_atoms =
      case nome_da_regra do
        {:__aliases__, _, parts} -> parts
        other when is_atom(other) -> [other]
      end

    modulo = Module.concat([__CALLER__.module | name_atoms])

    quote do
      defmodule unquote(modulo) do
        @moduledoc false

        def avaliar(var!(memoria)), do: unquote(condicao)
        # Referência a memoria evita warning de variável não usada quando a ação não a usa
        def executar(var!(memoria)),
          do:
            (
              var!(memoria)
              unquote(acao)
            )

        def start_link do
          Tec0301Pon.PON.Regra.start_link(unquote(fatos), __MODULE__)
        end
      end
    end
  end
end
