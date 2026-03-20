defmodule SimulacoesVisuaisWeb.TechGlossary do
  @moduledoc """
  Definições de termos técnicos (PT) para `<abbr>`, glossários em página e testes.
  """

  @entries %{
    pon: %{
      label: "PON",
      abbr_title:
        "Paradigma Orientado a Notificações: quando um atributo de um FBE muda, só as regras que o observam são reavaliadas.",
      definition:
        "Paradigma Orientado a Notificações. Modelo em que entidades de domínio (FBEs) notificam mudanças de estado; as regras subscrevem atributos e só executam avaliação e ação quando recebem notificação, em vez de varrer todo o sistema."
    },
    fbe: %{
      label: "FBE",
      abbr_title:
        "Elemento de Base de Fatos: unidade do domínio com atributos (fatos) e métodos acionados por regras.",
      definition:
        "Elemento de Base de Fatos. Entidade que representa equipamento ou subsistema no gêmeo digital: expõe atributos cujas mudanças notificam regras e métodos que as regras podem instigar."
    },
    oee: %{
      label: "OEE",
      abbr_title:
        "Overall Equipment Effectiveness (eficácia global do equipamento): produto de disponibilidade, performance e qualidade.",
      definition:
        "Overall Equipment Effectiveness. Indicador de eficácia da produção, frequentemente decomposto em disponibilidade (tempo útil), performance (ritmo) e qualidade (refugo). Aqui usa-se a abordagem Nakajima para A, P e Q."
    },
    tsdb: %{
      label: "TSDB",
      abbr_title:
        "Base de dados de séries temporais, otimizada para pontos ordenados no tempo (telemetria, métricas).",
      definition:
        "Time Series Database. Armazenamento orientado a séries temporais usado para telemetria, histórico de fatos e predições ML importadas para o painel."
    },
    spc: %{
      label: "SPC",
      abbr_title:
        "Statistical Process Control: controlo estatístico de processo com limites (ex.: três sigmas).",
      definition:
        "Statistical Process Control (controlo estatístico do processo). Uso de gráficos e limites de controlo (como UCL/LCL) para monitorizar variabilidade e detectar causas especiais."
    },
    ucl: %{
      label: "UCL",
      abbr_title: "Upper Control Limit — limite superior de controlo estatístico (SPC).",
      definition:
        "Upper Control Limit. Limite superior do gráfico de controlo; valores sustentados acima indicam varição anómala face ao processo estável."
    },
    lcl: %{
      label: "LCL",
      abbr_title: "Lower Control Limit — limite inferior de controlo estatístico (SPC).",
      definition:
        "Lower Control Limit. Limite inferior do gráfico de controlo; valores sustentados abaixo indicam varição anómala face ao processo estável."
    },
    bi: %{
      label: "BI",
      abbr_title:
        "Business Intelligence: painéis e consultas analíticas sobre dados do processo.",
      definition:
        "Business Intelligence (inteligência de negócio). Visualizações e agregados (gráficos, KPIs) construídos sobre dados armazenados, aqui integrados de forma nativa na aplicação Phoenix."
    },
    ml: %{
      label: "ML",
      abbr_title:
        "Machine Learning — modelos que aprendem padrões nos dados para prever ou classificar.",
      definition:
        "Machine Learning (aprendizagem automática). Modelos treinados externamente cujas predições podem ser importadas para a tabela `ml_predictions` e consultadas nesta plataforma."
    },
    liveview: %{
      label: "LiveView",
      abbr_title:
        "Phoenix LiveView: interface web atualizada no servidor com ligação WebSocket, sem JavaScript obrigatório no cliente.",
      definition:
        "Biblioteca Phoenix que renderiza HTML no servidor e envia diferenças ao browser via WebSocket, permitindo interfaces reativas com estado no servidor."
    },
    amr: %{
      label: "AMR",
      abbr_title: "Autonomous Mobile Robot — robô móvel autónomo (logística interna).",
      definition:
        "Autonomous Mobile Robot. Veículo robótico que navega de forma autónoma no chão de fábrica; no cenário Smart Brewery participa em missões e intertravamentos com a linha de envase."
    },
    v2g: %{
      label: "V2G",
      abbr_title: "Vehicle-to-Grid: fluxo de energia entre veículos elétricos e a rede elétrica.",
      definition:
        "Vehicle-to-Grid. Capacidade de bidirecionalidade energética entre baterias de veículos e a rede; usado nas regras de Smart Grid para suportar picos de tarifa."
    },
    lmtd: %{
      label: "LMTD",
      abbr_title:
        "Log Mean Temperature Difference — média logarítmica das diferenças de temperatura num trocador.",
      definition:
        "Log Mean Temperature Difference. Grandeza usada no dimensionamento e análise de trocadores de calor; nas regras do demo relaciona eficiência de arrefecimento do mosto."
    },
    cip: %{
      label: "CIP",
      abbr_title: "Clean-In-Place: limpeza automática dos circuitos sem desmontar equipamento.",
      definition:
        "Clean-In-Place (limpeza no local). Sistema de lavagem e desinfeção em circuito fechado típico em cervejarias; modelado como FBE com bomba, tanques e condutividade."
    },
    nr_13: %{
      label: "NR-13",
      abbr_title: "Norma Regulamentadora 13 (Brasil) — caldeiras, vasos de pressão e tubulações.",
      definition:
        "NR-13 do Ministério do Trabalho (Brasil). Regulamenta inspeção, manutenção e operação de caldeiras e vasos de pressão; citada no contexto de segurança da caldeira de fervura."
    },
    isa_88: %{
      label: "ISA-88",
      abbr_title: "Norma de modelação de processos descontínuos (batch) na indústria.",
      definition:
        "ANSI/ISA-88. Modelo de receitas, fases e operações para processos batch; referência para intertravamentos entre mostura e filtração."
    },
    gemeo_digital: %{
      label: "Gêmeo digital",
      abbr_title:
        "Representação digital viva de um sistema físico, sincronizada com dados em tempo real.",
      definition:
        "Gêmeo digital (digital twin). Modelo computacional do processo físico alimentado por sensores e regras, usado para monitorização, simulação e decisão."
    },
    industria_4: %{
      label: "Indústria 4.0",
      abbr_title:
        "Quarta revolução industrial: IoT, dados em tempo real e sistemas ciber-físicos.",
      definition:
        "Indústria 4.0. Integração de produção com sensores, conectividade e análise de dados para fabrico adaptativo e transparente."
    },
    timestamp_utc: %{
      label: "ts",
      abbr_title: "Carimbo temporal em UTC — instante em que a predição foi registada.",
      definition:
        "Timestamp (marca temporal) em tempo universal coordenado (UTC). Indica quando o valor predito foi gravado na base de séries temporais."
    },
    modelo_ml: %{
      label: "modelo",
      abbr_title:
        "Nome identificador do modelo de aprendizagem automática que produziu a predição.",
      definition:
        "Identificador do modelo ML (por exemplo, ficheiro ou pipeline de treino) associado a cada linha importada em `ml_predictions`."
    },
    alvo_ml: %{
      label: "alvo",
      abbr_title: "Variável ou grandeza que o modelo prevê (target).",
      definition:
        "Target ou variável-alvo da predição: o que o modelo estima (ex.: OEE futuro, classe de anomalia), quando aplicável."
    },
    valor_predicao: %{
      label: "valor",
      abbr_title: "Saída numérica ou escalar da predição importada.",
      definition:
        "Valor numérico produzido pelo modelo para o instante e alvo indicados; armazenado como ponto flutuante na importação."
    },
    digital_twin_en: %{
      label: "Digital Twin",
      abbr_title:
        "Equivalente em inglês de gêmeo digital — modelo sincronizado com o sistema real.",
      definition:
        "Digital Twin. Termo em inglês para gêmeo digital: representação virtual do processo atualizada com telemetria e regras de negócio."
    },
    regra_pon: %{
      label: "Regra",
      abbr_title:
        "No PON, agrega premissas sobre fatos e ações: avaliada quando um atributo observado muda; se a condição for verdadeira, executa a ação.",
      definition:
        "Regra de produção. Observa um conjunto de atributos de FBEs; quando algum notifica mudança, reavalia condições (AND/OR) e, se satisfeitas, instiga métodos nos FBEs alvo."
    },
    fato_pon: %{
      label: "Fato",
      abbr_title:
        "No PON, valor corrente de um atributo de FBE; quando muda, notifica só as regras que o observam.",
      definition:
        "Fato (fact). Instância de dado de processo associada a um atributo de um FBE; a sua alteração é o evento que dispara reavaliação selectiva das regras no paradigma orientado a notificações."
    },
    premissa_pon: %{
      label: "Premissa",
      abbr_title:
        "Condição atómica numa regra PON: compara o valor de um fato (atributo de FBE) a um critério.",
      definition:
        "Premissa. Parte elementar da condição de uma regra, tipicamente ligada a um único atributo observado; várias premissas combinam-se com AND/OR antes da ação."
    },
    monte_carlo: %{
      label: "Monte Carlo",
      abbr_title:
        "Simulação estocástica: amostragem aleatória repetida para variar fatos e stressar o runtime e o TSDB.",
      definition:
        "Método de Monte Carlo. No demo, gera atualizações pseudo-aleatórias periódicas dos fatos para exercitar regras, telemetria e persistência sem um roteiro fixo."
    },
    oee_availability: %{
      label: "A",
      abbr_title: "Disponibilidade (Nakajima): tempo de produção útil face ao tempo planeado.",
      definition:
        "Componente A do OEE. Mede perdas de disponibilidade (paragens, mudanças, falhas) na descomposição clássica de Nakajima."
    },
    oee_performance: %{
      label: "P",
      abbr_title: "Performance (Nakajima): ritmo real de produção face ao ritmo ideal.",
      definition:
        "Componente P do OEE. Capta perdas de velocidade (ciclos lentos, micro-paragens) relativamente ao máximo teórico."
    },
    oee_quality: %{
      label: "Q",
      abbr_title:
        "Qualidade (Nakajima): quantidade boa face ao total processado (refugo/retrabalho).",
      definition:
        "Componente Q do OEE. Reflete perdas de qualidade: unidades fora de especificação ou retrabalho."
    },
    smart_grid: %{
      label: "Smart Grid",
      abbr_title:
        "Rede elétrica inteligente integrada ao processo: tarifas, V2G, falhas e resposta de carga (FBE_11 no demo).",
      definition:
        "Smart Grid. Modelo do sistema energético com custo de tarifa, armazenamento V2G e deteção de falha; as regras cruzam fermentação, CIP e AMRs para gestão de picos e resiliência."
    },
    anomalia_processo: %{
      label: "Anomalia",
      abbr_title:
        "Desvio estatístico face a um modelo de referência (EMA): valor fora dos limites esperados para o fato.",
      definition:
        "Anomalia de processo. Marcador quando a telemetria se afasta significativamente da tendência suavizada usada como referência, alertando para causas especiais potenciais."
    },
    sparkline: %{
      label: "Sparkline",
      abbr_title:
        "Gráfico de linha minimalista (série temporal compacta) sem eixos, para tendência rápida nos tiles.",
      definition:
        "Sparkline. Pequena série temporal desenhada inline; aqui mostra evolução recente do fato representativo de cada FBE quando o TSDB está ativo."
    },
    cl_spc: %{
      label: "CL",
      abbr_title:
        "Center Line (linha central): valor central de referência do processo estável no gráfico de controlo.",
      definition:
        "Linha central em SPC. Estimativa do nível do processo sob controlo; UCL e LCL simétricos delimitam a variação comum esperada."
    },
    cep_ichart: %{
      label: "CEP · I-Chart",
      abbr_title:
        "Carta de controlo individual (Shewhart tipo I) para uma variável ao longo do tempo — aqui telemetria associada a AMR.",
      definition:
        "Carta I (individual). Gráfico de controlo onde cada ponto é uma observação individual; útil para variáveis contínuas com agregação temporal. O painel mostra CL, UCL e LCL calculados no backend."
    },
    painel_sinotico: %{
      label: "Painel sinótico",
      abbr_title:
        "Vista resumida do estado do processo: por FBE, indicador ok/warning a partir de médias agregadas.",
      definition:
        "Sinótico. Representação simplificada tipo painel de operador com estados agregados por equipamento, sem o detalhe de cada fato."
    },
    diagrama_pareto: %{
      label: "Pareto",
      abbr_title:
        "Diagrama de Pareto: ordenação das causas ou eventos mais frequentes (princípio 80/20).",
      definition:
        "Análise de Pareto. Barras ordenadas por frequência ou impacto; aqui usada para top anomalias e top regras disparadas no intervalo filtrado."
    },
    correlacao_fisica: %{
      label: "Correlação física",
      abbr_title:
        "Cruzamento de variáveis de processo (filtração tipo Darcy, fermentação) para leitura conjunta, não causal inferida.",
      definition:
        "Vista de correlação física. Tabela de pontos alinhados no tempo entre pressão, claridade, bomba, Brix, CO₂ e pH para suportar interpretação do demo multiphysics."
    },
    serie_temporal_telemetria: %{
      label: "Série temporal",
      abbr_title:
        "Sequência de valores ordenados no tempo (telemetria agregada pela granularidade do filtro BI).",
      definition:
        "Série temporal. Pontos (t, valor) armazenados ou agregados no TSDB e mostrados como tendência no painel analítico."
    },
    load_shedding: %{
      label: "Load shedding",
      abbr_title:
        "Redução selectiva de cargas não críticas quando a rede falha ou em modo ilha (regra de resiliência).",
      definition:
        "Load shedding. Desligar ou diminuir consumidores secundários para preservar alimentação de processos essenciais; citado na R_12 com modo ilha e V2G."
    },
    iso_10816: %{
      label: "ISO 10816-3",
      abbr_title:
        "Norma para avaliação de vibração em máquinas industriais — referência da regra de proteção do moinho.",
      definition:
        "ISO 10816-3. Define zonas de severidade de vibração em equipamentos rotativos; no demo informa limites conceituais para o FBE_01."
    }
  }

  @doc """
  Lista de chaves sugeridas por página (glossário compacto).
  """
  def terms_for(:home) do
    [:pon, :fbe, :regra_pon, :liveview, :gemeo_digital, :industria_4, :ml]
  end

  def terms_for(:ml_predictions) do
    [:ml, :tsdb, :timestamp_utc, :modelo_ml, :alvo_ml, :valor_predicao]
  end

  def terms_for(:smart_brewery) do
    [
      :gemeo_digital,
      :pon,
      :fato_pon,
      :fbe,
      :premissa_pon,
      :regra_pon,
      :oee,
      :oee_availability,
      :oee_performance,
      :oee_quality,
      :monte_carlo,
      :tsdb,
      :liveview,
      :smart_grid,
      :spc,
      :ucl,
      :lcl,
      :cl_spc,
      :anomalia_processo,
      :sparkline,
      :bi,
      :serie_temporal_telemetria,
      :cep_ichart,
      :correlacao_fisica,
      :painel_sinotico,
      :diagrama_pareto,
      :digital_twin_en,
      :ml,
      :amr,
      :v2g,
      :lmtd,
      :cip,
      :nr_13,
      :isa_88,
      :iso_10816,
      :load_shedding
    ]
  end

  @doc """
  Fragmento HTML id estável: `glossario-pon`, `glossario-nr-13`, etc.
  """
  def fragment_id(term) when is_atom(term) do
    "glossario-" <> slug(term)
  end

  def definition_fragment_id(term) when is_atom(term) do
    fragment_id(term) <> "-def"
  end

  @doc """
  Retorna `%{label:, abbr_title:, definition:}` ou levanta se a chave não existir.
  """
  def entry!(term) when is_atom(term) do
    case Map.fetch(@entries, term) do
      {:ok, e} -> e
      :error -> raise ArgumentError, "unknown glossary term: #{inspect(term)}"
    end
  end

  @doc """
  Versão segura para templates dinâmicos.
  """
  def entry(term) when is_atom(term), do: Map.get(@entries, term)

  defp slug(term) do
    term |> Atom.to_string() |> String.replace("_", "-")
  end
end
