defmodule Tec0301Pon.Examples.SmartBrewery do
  @moduledoc """
  Gêmeo Digital da Smart Brewery (Artigo 05/06/07). Prova de Conceito PON com 57 fatos
  distribuídos em 11 Elementos de Bloco Funcional (FBEs) e 12 regras de negócio (R_01 a R_12, Artigo 05 e 11).

  ## Mapeamento 57 fatos ↔ 11 FBEs (lista completa)

  | FBE | Nome           | Fatos (todos) |
  | 01  | Moinho_Malte   | fbe_01_motor_rpm, fbe_01_vibration_level, fbe_01_hopper_level, fbe_01_motor_temp, fbe_01_feed_valve_state |
  | 02  | Tanque_Mostura | fbe_02_mash_temp, fbe_02_water_flow_rate, fbe_02_agitator_status, fbe_02_ph_level, fbe_02_viscosity, fbe_02_liquid_level |
  | 03  | Tina_Filtro    | fbe_03_diff_pressure, fbe_03_wort_clarity, fbe_03_sparge_water_temp, fbe_03_rake_height, fbe_03_pump_speed |
  | 04  | Caldeira_Fervura | fbe_04_boil_temp, fbe_04_steam_pressure, fbe_04_evaporation_rate, fbe_04_hop_doser_state, fbe_04_foam_level |
  | 05  | Trocador_Calor | fbe_05_wort_in_temp, fbe_05_wort_out_temp, fbe_05_glycol_valve_pos, fbe_05_water_pressure |
  | 06  | Fermentador_A  | fbe_06_internal_temp, fbe_06_pressure, fbe_06_gravity_brix, fbe_06_glycol_jacket_st, fbe_06_co2_exhaust_flow, fbe_06_ferm_phase, fbe_06_ph |
  | 07  | Fermentador_B  | fbe_07_internal_temp, fbe_07_pressure, fbe_07_gravity_brix, fbe_07_glycol_jacket_st, fbe_07_co2_exhaust_flow, fbe_07_ferm_phase |
  | 08  | Linha_Envase   | fbe_08_ir_bottle_detect, fbe_08_conveyor_speed, fbe_08_fill_head_status, fbe_08_liquid_lvl_detect, fbe_08_capper_jam_sens, fbe_08_stop_sensor |
  | 09  | Sistema_CIP    | fbe_09_caustic_tank_lvl, fbe_09_acid_tank_lvl, fbe_09_return_conduct, fbe_09_cip_pump_state, fbe_09_flow_velocity |
  | 10  | Frota_AMR      | fbe_10_robot_1_battery, fbe_10_robot_1_location, fbe_10_robot_1_status, fbe_10_collision_alert, fbe_10_payload_weight |
  | 11  | Smart_Grid     | fbe_11_grid_power_cost, fbe_11_v2g_battery_lvl, fbe_11_main_load_draw, fbe_11_grid_fault_detec |

  Total: 5+6+5+5+4+7+6+6+5+5+4 = 57 fatos.

  ## 12 regras PON (detalhe)

  - **R_01** RegraOtimizacaoFiltracao (FBE_03). **R_02** RegraIntertravamentoEnvase (FBE_08, FBE_10). **R_03** RegraSmartGridLoadBalancing (FBE_06, FBE_11).
  - **R_04** RegraProtecaoMoinho (FBE_01, ISO 10816-3). **R_05** RegraControleMostura (FBE_02). **R_06** RegraSegurancaCaldeira (FBE_04, NR-13). **R_07** RegraOtimizacaoTrocador (FBE_05). **R_08** RegraLoadBalancingFermentadorB (FBE_07, FBE_11). **R_09** RegraIntertravamentoMosturaFiltro (FBE_02, FBE_03, ISA-88). **R_10** RegraIntertravamentoFervuraTrocador (FBE_04, FBE_05). **R_11** RegraGestaoBateriaAMR (FBE_10). **R_12** RegraResilienciaRede (FBE_11).

  O Registry (PON) deve já estar rodando. A ordem de inicialização recomendada é: Bridge (malha PON) antes do Monte Carlo.

  Documentação detalhada de **cada fato (tipo, valor inicial)** e **cada regra (`watch`, condição, ações)**:
  [`docs/smart-brewery-fatos-regras.md`](../../../docs/smart-brewery-fatos-regras.md).

  Textos de interface por fato (UI/a11y) na app Phoenix: `SimulacoesVisuais.SmartBrewery.FatoDescriptions`.
  """
  alias Tec0301Pon.PON.Fato

  # Lista dos 57 fatos com valores iniciais (Tabelas 1–3 do artigo 05)
  @fatos_iniciais [
    # FBE_01 Moinho_Malte (5)
    {:fbe_01_motor_rpm, 0},
    {:fbe_01_vibration_level, 0},
    {:fbe_01_hopper_level, 80},
    {:fbe_01_motor_temp, 45},
    {:fbe_01_feed_valve_state, :closed},
    # FBE_02 Tanque_Mostura (6)
    {:fbe_02_mash_temp, 65},
    {:fbe_02_water_flow_rate, 0},
    {:fbe_02_agitator_status, :off},
    {:fbe_02_ph_level, 5.2},
    {:fbe_02_viscosity, 0},
    {:fbe_02_liquid_level, 0},
    # FBE_03 Tina_Filtro (5) — R_01: diff_pressure 80, wort_clarity 25, pump_speed 40 para cenário
    {:fbe_03_diff_pressure, 80},
    {:fbe_03_wort_clarity, 25},
    {:fbe_03_sparge_water_temp, 75},
    {:fbe_03_rake_height, 50},
    {:fbe_03_pump_speed, 40},
    # FBE_04 Caldeira_Fervura (5)
    {:fbe_04_boil_temp, 0},
    {:fbe_04_steam_pressure, 0},
    {:fbe_04_evaporation_rate, 0},
    {:fbe_04_hop_doser_state, :idle},
    {:fbe_04_foam_level, 0},
    # FBE_05 Trocador_Calor (4)
    {:fbe_05_wort_in_temp, 0},
    {:fbe_05_wort_out_temp, 0},
    {:fbe_05_glycol_valve_pos, 0},
    {:fbe_05_water_pressure, 0},
    # FBE_06 Fermentador_A (7) — R_03: internal_temp < 19; pH por subprodutos (artigo 06)
    {:fbe_06_internal_temp, 18},
    {:fbe_06_pressure, 0},
    {:fbe_06_gravity_brix, 0},
    {:fbe_06_glycol_jacket_st, :on},
    {:fbe_06_co2_exhaust_flow, 0},
    {:fbe_06_ferm_phase, :lag},
    {:fbe_06_ph, 5.2},
    # FBE_07 Fermentador_B (6)
    {:fbe_07_internal_temp, 18},
    {:fbe_07_pressure, 0},
    {:fbe_07_gravity_brix, 0},
    {:fbe_07_glycol_jacket_st, :off},
    {:fbe_07_co2_exhaust_flow, 0},
    {:fbe_07_ferm_phase, :lag},
    # FBE_08 Linha_Envase (6) — R_02: liquid_lvl_detect :ok inicial
    {:fbe_08_ir_bottle_detect, false},
    {:fbe_08_conveyor_speed, 0},
    {:fbe_08_fill_head_status, :idle},
    {:fbe_08_liquid_lvl_detect, :ok},
    {:fbe_08_capper_jam_sens, false},
    {:fbe_08_stop_sensor, false},
    # FBE_09 Sistema_CIP (5) — R_03: cip_pump_state :on para disparar
    {:fbe_09_caustic_tank_lvl, 80},
    {:fbe_09_acid_tank_lvl, 80},
    {:fbe_09_return_conduct, 0},
    {:fbe_09_cip_pump_state, :off},
    {:fbe_09_flow_velocity, 0},
    # FBE_10 Frota_AMR (5) — R_02: collision_alert false
    {:fbe_10_robot_1_battery, 100},
    {:fbe_10_robot_1_location, {0, 0}},
    {:fbe_10_robot_1_status, :ocioso},
    {:fbe_10_collision_alert, false},
    {:fbe_10_payload_weight, 0},
    # FBE_11 Smart_Grid (4) — R_03: grid_power_cost > 150
    {:fbe_11_grid_power_cost, 100},
    {:fbe_11_v2g_battery_lvl, 80},
    {:fbe_11_main_load_draw, 0},
    {:fbe_11_grid_fault_detec, false}
  ]

  @fatos_names Enum.map(@fatos_iniciais, fn {nome, _valor} -> nome end)

  @doc """
  Retorna a lista de átomos que representam os 57 fatos do Gêmeo Digital.

  Usado pela camada de visualização (ex.: LiveView) para inicializar e subscrever
  o estado de maneira determinística.
  """
  def fatos_names, do: @fatos_names

  @doc """
  Inicia a malha PON da Smart Brewery: 57 fatos e 12 regras (Artigo 05 e 11).
  """
  def start_link do
    for {nome, valor} <- @fatos_iniciais do
      Fato.start_link(nome, valor)
    end

    Tec0301Pon.Examples.SmartBrewery.Regras.RegraOtimizacaoFiltracao.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoEnvase.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraSmartGridLoadBalancing.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraProtecaoMoinho.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraControleMostura.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraSegurancaCaldeira.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraOtimizacaoTrocador.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraLoadBalancingFermentadorB.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoMosturaFiltro.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoFervuraTrocador.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraGestaoBateriaAMR.start_link()
    Tec0301Pon.Examples.SmartBrewery.Regras.RegraResilienciaRede.start_link()

    {:ok, self()}
  end

  @doc """
  Simula o efeito cascata da sec. 6.1 do artigo: diff_pressure sobe para 152 mbar com
  wort_clarity < 20 e pump_speed > 50, disparando R_01. Opcionalmente dispara R_02 e R_03.
  """
  def simular do
    IO.puts("--- Smart Brewery (Artigo 05): simulação ---")
    Process.sleep(500)

    # Pré-condições para R_01: P2 e P3 já verdadeiras (wort_clarity < 20, pump_speed > 50)
    IO.puts("\n[Telemetria] Ajustando wort_clarity e pump_speed para cenário de filtração.")
    Fato.atualizar(:fbe_03_wort_clarity, 15)
    Fato.atualizar(:fbe_03_pump_speed, 60)
    Process.sleep(800)

    # Minuto 86: diff_pressure sobe para 152 mbar → P1 passa a verdadeiro → R_01 dispara
    IO.puts("\n[Telemetria] Pressão diferencial subiu para 152 mbar (compactação do leito).")
    Fato.atualizar(:fbe_03_diff_pressure, 152)
    Process.sleep(1500)

    # Opcional: R_02 — intertravamento envase
    IO.puts("\n[Telemetria] Simulando encravamento na arrolhadora (capper_jam_sens).")
    Fato.atualizar(:fbe_08_capper_jam_sens, true)
    Process.sleep(1200)

    # Opcional: R_03 — Smart Grid (internal_temp < 19, cip_pump_state :on, grid_power_cost > 150)
    IO.puts("\n[Telemetria] Simulando pico de tarifa e CIP ligado para R_03.")
    Fato.atualizar(:fbe_09_cip_pump_state, :on)
    Fato.atualizar(:fbe_11_grid_power_cost, 180)
    Process.sleep(800)

    IO.puts("\n--- Fim da simulação ---")
  end
end
