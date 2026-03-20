defmodule Tec0301Pon.PON.ReteSpike do
  @moduledoc """
  Prova de conceito **Rete** com [Retex](https://hexdocs.pm/retex/) (artigo 20, §4): duas
  condições atômicas compartilham a rede alfa/beta em vez de reavaliar o mesmo predicado
  em N processos `Regra`.

  Mapeamento sugerido para o PON: cada `Fato` atômico vira um `Retex.Wme` com
  identificador de entidade (ex. equipamento), atributo (nome lógico do fato) e valor.

  Este módulo **não** substitui `Tec0301Pon.PON.Regra`; serve como base para experimentos
  e testes de regressão da biblioteca.
  """

  alias Retex.Fact.HasAttribute

  @doc """
  Constrói uma rede mínima estilo Smart Brewery: se fermentador está quente **e** pressão
  alta, a agenda contém um nó de produção (ação como lista de WMEs).

  Retex exige pelo menos **duas** condições no `given` para formar o join beta.
  """
  @spec sample_rule() :: map()
  def sample_rule do
    %{
      given: [
        HasAttribute.new(
          owner: :Fermentador_A,
          attribute: :internal_temp,
          predicate: :>,
          value: 22.0
        ),
        HasAttribute.new(
          owner: :Fermentador_A,
          attribute: :pressure,
          predicate: :>,
          value: 1.0
        )
      ],
      then: [Retex.Wme.new(:Sistema, :thermal_alert, :on)]
    }
  end

  @doc """
  Executa inferência: adiciona a regra, insere WMEs que satisfazem ambas as condições e
  devolve `{network, agenda_length}`.
  """
  @spec run_demo() :: {Retex.t(), non_neg_integer()}
  def run_demo do
    network =
      Retex.new()
      |> Retex.add_production(sample_rule())
      |> Retex.add_wme(Retex.Wme.new(:Fermentador_A, :internal_temp, 23.5))
      |> Retex.add_wme(Retex.Wme.new(:Fermentador_A, :pressure, 1.2))

    {network, length(network.agenda)}
  end

  @doc """
  Mesmo cenário com pressão baixa: join não fecha, agenda vazia.
  """
  @spec run_negative_demo() :: {Retex.t(), non_neg_integer()}
  def run_negative_demo do
    network =
      Retex.new()
      |> Retex.add_production(sample_rule())
      |> Retex.add_wme(Retex.Wme.new(:Fermentador_A, :internal_temp, 23.5))
      |> Retex.add_wme(Retex.Wme.new(:Fermentador_A, :pressure, 0.2))

    {network, length(network.agenda)}
  end
end
