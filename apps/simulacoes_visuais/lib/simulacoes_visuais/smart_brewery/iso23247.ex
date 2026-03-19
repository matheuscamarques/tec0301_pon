defmodule SimulacoesVisuais.SmartBrewery.ISO23247 do
  @moduledoc """
  Mapeamento dos componentes do projeto Smart Brewery para a norma ISO 23247
  (Digital Twin Framework for Manufacturing), conforme artigo 12.

  Ver também: `docs/artigos/12_mapeamento_iso_23247.md`.
  """

  @doc """
  Retorna um mapa que associa cada bloco da ISO 23247 aos componentes do projeto.
  """
  def map_components do
    %{
      entity_physical: %{
        description: "Entidade Física: ativos, equipamentos e ambiente do chão de fábrica",
        components: [
          "11 FBEs: Moinho_Malte, Tanque_Mostura, Tina_Filtro, Caldeira_Fervura, Trocador_Calor, Fermentador_A, Fermentador_B, Linha_Envase, Sistema_CIP, Frota_AMR, Smart_Grid",
          "57 fatos PON (Tec0301Pon.PON.Fato) representando sensores e atuadores"
        ]
      },
      data_collection_network: %{
        description: "Rede de Coleta de Dados: amostragem, borda e transmissão de telemetria",
        components: [
          "PON (notificações de fatos)",
          "SmartBreweryFactBroadcaster",
          "TelemetryPipeline (Broadway/GenStage)",
          "SmartBreweryTelemetryBatcher"
        ]
      },
      digital_representation: %{
        description: "Representação Digital (Core Twin): modelos e atores de software",
        components: [
          "57 processos Fato + regras PON R_01 a R_12",
          "FBE03Darcy, FBE06Fermentation, FBE07Fermentation",
          "FBE08Markov, FBE10Markov, FBE11SmartGrid",
          "SmartBrewery.OEE, SmartBrewery.EMA"
        ]
      },
      information_exchange_plan: %{
        description: "Plano de Intercâmbio: APIs e esquemas de comunicação",
        components: [
          "Phoenix.PubSub: smart_brewery:fatos, smart_brewery:oee, smart_brewery:anomalias",
          "Formato: {:batch, updates}, {:oee, pct}, {:anomalia, nome_fato, valor, ema, sigma}"
        ]
      },
      cross_entity_applications: %{
        description: "Aplicações de Entidades Cruzadas: decisão e visualização",
        components: [
          "Regras PON (R_01, R_02, R_03, ...) e ações nos FBEs",
          "SmartBreweryLive (painel LiveView)",
          "Consumidores de OEE e anomalias"
        ]
      }
    }
  end
end
