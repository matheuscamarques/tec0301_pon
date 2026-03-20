defmodule SimulacoesVisuais.SmartBrewery.FatoDescriptions do
  @moduledoc """
  Textos curtos para UI e acessibilidade dos fatos do gêmeo Smart Brewery.

  Vive na app `simulacoes_visuais` para ser sempre recompilada com o Phoenix (evita BEAM
  desatualizado da dependência `path` `tec0301_pon` em sessões `iex -S mix phx.server`).

  Deve cobrir os mesmos átomos que `Tec0301Pon.Examples.SmartBrewery.fatos_names/0`.
  Referência: `docs/smart-brewery-fatos-regras.md`.
  """

  @descriptions %{
    fbe_01_motor_rpm:
      "Rotação do motor do moinho (RPM). Indica carga de moagem; mudanças notificam regras que observam o FBE_01.",
    fbe_01_vibration_level:
      "Nível de vibração do equipamento (mm/s, referência ISO 10816-3 na R_04). Sinal de desgaste ou desalinhamento; notifica a proteção do moinho.",
    fbe_01_hopper_level:
      "Enchimento do funil de alimentação (%). Evita moagem a seco; usado na R_04 com RPM e válvula de carga.",
    fbe_01_motor_temp:
      "Temperatura do motor (°C). Proteção térmica; premissa da R_04 (Proteção Moinho).",
    fbe_01_feed_valve_state:
      "Estado da válvula de alimentação do malte (ex.: fechada ou aberta). Ações das regras podem fechá-la em vibração crítica.",
    fbe_02_mash_temp:
      "Temperatura do mosto na mostura (°C). Faixa enzimática típica 60–72 °C; observada pela R_05 e R_09.",
    fbe_02_water_flow_rate:
      "Vazão de água de infusão ou ajuste (L/min). Usada pela R_05 para corrigir temperatura/pH.",
    fbe_02_agitator_status:
      "Agitador ligado ou desligado. Garante homogeneização; R_05 reage se o nível estiver alto com agitador parado.",
    fbe_02_ph_level: "pH do mosto. Faixa de trabalho típica 5,0–5,8; premissa da R_05.",
    fbe_02_viscosity:
      "Viscosidade aparente (cP). Indica conversão do amido; telemetria de processo.",
    fbe_02_liquid_level:
      "Nível de líquido no tanque (%). Intertravamento com bomba da filtração (R_09) e R_05.",
    fbe_03_diff_pressure:
      "Pressão diferencial no leito de filtração (mbar). Subida indica compactação; chave na R_01.",
    fbe_03_wort_clarity:
      "Claridade/turbidez do mosto filtrado (valor relativo % na simulação). Junto com pressão e bomba define R_01.",
    fbe_03_sparge_water_temp:
      "Temperatura da água de lavagem (sparge) (°C). Afeta extração e qualidade da filtração.",
    fbe_03_rake_height:
      "Altura das facas/raspadores (%). Ajustada pelas ações da R_01 para aliviar o leito.",
    fbe_03_pump_speed:
      "Velocidade da bomba de recirculação/transf. (%). Alta com mostura imprópria dispara R_09; integra R_01.",
    fbe_04_boil_temp:
      "Temperatura de fervura do mosto (°C). Usada em R_06 (segurança) e R_10 (intertravamento com trocador).",
    fbe_04_steam_pressure:
      "Pressão de vapor na caldeira (bar). Limite de segurança NR-13 na R_06.",
    fbe_04_evaporation_rate:
      "Taxa de evaporação (%). Indica intensidade da fervura e perda de volume.",
    fbe_04_hop_doser_state:
      "Estado do dosador de lúpulo (ex.: ocioso). R_06 pode pausar o dosador em condições inseguras.",
    fbe_04_foam_level: "Nível de espuma (%). Espuma excessiva é premissa de segurança na R_06.",
    fbe_05_wort_in_temp:
      "Temperatura do mosto à entrada do trocador (°C). Usada na R_07 (LMTD) e na R_10.",
    fbe_05_wort_out_temp:
      "Temperatura do mosto à saída (°C). Indica eficiência de resfriamento; observada na R_07.",
    fbe_05_glycol_valve_pos:
      "Abertura da válvula de glicol (%). Aumentada pelas regras para mais capacidade térmica (R_07, R_10).",
    fbe_05_water_pressure:
      "Pressão do circuito de água/glicol (bar). Monitoramento hidráulico do trocador.",
    fbe_06_internal_temp:
      "Temperatura interna do mosto (°C). Estabilidade < 19 °C entra na R_03 (Smart Grid).",
    fbe_06_pressure: "Pressão no fermentador (bar). Segurança e perfil de fermentação.",
    fbe_06_gravity_brix: "Grau Brix (densidade do mosto). Acompanha conversão de açúcares.",
    fbe_06_glycol_jacket_st:
      "Resfriamento por jaqueta de glicol ligado ou desligado. R_03 pode pausar o resfriamento em pico tarifário.",
    fbe_06_co2_exhaust_flow: "Vazão de CO₂ na saída (L/min). Indica atividade da fermentação.",
    fbe_06_ferm_phase: "Fase da fermentação (ex.: lag). Contexto operacional do processo.",
    fbe_06_ph: "pH durante a fermentação. Monitoramento de subprodutos e saúde do processo.",
    fbe_07_internal_temp:
      "Temperatura interna do fermentador B (°C). Observada na R_08 com tarifa e V2G.",
    fbe_07_pressure: "Pressão no brite tank (bar). Mesma função que no fermentador A.",
    fbe_07_gravity_brix: "Grau Brix no fermentador B. Acompanhamento de atenuação.",
    fbe_07_glycol_jacket_st:
      "Estado da jaqueta de glicol no B. R_08 pode pausar resfriamento em pico de energia.",
    fbe_07_co2_exhaust_flow: "Vazão de CO₂ (L/min) no fermentador B.",
    fbe_07_ferm_phase: "Fase fermentativa no tanque B.",
    fbe_08_ir_bottle_detect:
      "Deteção infravermelha de garrafa na linha (verdadeiro/falso). Presença de envase.",
    fbe_08_conveyor_speed:
      "Velocidade da esteira (% ou escala da simulação). Parada de emergência na R_02.",
    fbe_08_fill_head_status:
      "Estado do bico de enchimento (ex.: ocioso). Sincronização da linha.",
    fbe_08_liquid_lvl_detect:
      "Diagnóstico do sensor de nível de líquido (:ok / :fail). Falha dispara R_02.",
    fbe_08_capper_jam_sens:
      "Sensor de encravamento na arrolhadora. Verdadeiro indica paragem crítica (R_02).",
    fbe_08_stop_sensor: "Sensor de parada da linha. Segurança de máquina.",
    fbe_09_caustic_tank_lvl:
      "Nível do tanque de cáustico (%). Disponibilidade de solução alcalina.",
    fbe_09_acid_tank_lvl: "Nível do tanque de ácido (%). Disponibilidade da etapa ácida.",
    fbe_09_return_conduct:
      "Condutividade do retorno (µS/cm). Indica remoção de resíduos e qualidade do CIP.",
    fbe_09_cip_pump_state:
      "Bomba CIP ligada ou desligada. Estado :on com tarifa alta integra a R_03.",
    fbe_09_flow_velocity:
      "Velocidade do fluxo na linha CIP (m/s). Verificação de turbulência eficaz.",
    fbe_10_robot_1_battery:
      "Carga da bateria do robô (%). R_11 solicita retorno ao carregador se baixa em missão.",
    fbe_10_robot_1_location:
      "Posição lógica do robô (coordenadas). Navegação e missões; não é escalar único no TSDB.",
    fbe_10_robot_1_status:
      "Estado operacional (ex.: ocioso, em missão). Usado com a bateria na R_11.",
    fbe_10_collision_alert: "Alerta de colisão. Verdadeiro contribui para R_02 (envase + AMR).",
    fbe_10_payload_weight: "Peso da carga transportada (kg). Logística e limites do AMR.",
    fbe_11_grid_power_cost:
      "Custo relativo da tarifa de energia. Acima de 150 (simulação) indica pico; R_03 e R_08.",
    fbe_11_v2g_battery_lvl:
      "Nível do buffer V2G (%). Descarga em picos quando acima do mínimo (R_03, R_08, R_12).",
    fbe_11_main_load_draw: "Demanda principal da planta (kW). Visão de carga elétrica agregada.",
    fbe_11_grid_fault_detec:
      "Falha na rede elétrica (verdadeiro/falso). Única premissa da R_12 (ilha, load shedding, V2G)."
  }

  @doc """
  Retorna texto descritivo do fato para tabelas, tooltips e leitores de ecrã.
  """
  @spec descricao(atom()) :: String.t()
  def descricao(nome) when is_atom(nome) do
    Map.get(@descriptions, nome, "")
  end

  @doc """
  Mesmo texto que `descricao/1`, para `fact_name` persistido como string (TSDB, Power BI push).
  """
  @spec descricao_bin(String.t()) :: String.t()
  def descricao_bin(fact_name) when is_binary(fact_name) do
    try do
      descricao(String.to_existing_atom(fact_name))
    rescue
      ArgumentError -> ""
    end
  end
end
