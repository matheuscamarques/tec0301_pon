defmodule Tec0301Pon.Examples.SmartBrewery.Regras do
  @moduledoc """
  Regras PON do Gêmeo Digital Smart Brewery (Artigo 05/06/07 e 11). Regras R_01 a R_12
  que observam os 57 fatos e acionam FBEs. Ver mapeamento em `Tec0301Pon.Examples.SmartBrewery`.

  - R_01 a R_03: Artigo 05 (otimização filtração, intertravamento envase, Smart Grid).
  - R_04 a R_12: Artigo 11 (proteção moinho, mostura, caldeira, trocador, ISA-88, AMR, resiliência rede).
  """
  use Tec0301Pon.PON.Builder

  # R_01: AND — diff_pressure > 150, wort_clarity < 20, pump_speed > 50
  defrule(RegraOtimizacaoFiltracao,
    watch: [:fbe_03_diff_pressure, :fbe_03_wort_clarity, :fbe_03_pump_speed],
    when:
      memoria[:fbe_03_diff_pressure] > 150 and memoria[:fbe_03_wort_clarity] < 20 and
        memoria[:fbe_03_pump_speed] > 50,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_03.reduce_pump_10pct()
        Tec0301Pon.Examples.SmartBrewery.FBE_03.lower_rake_position()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_01)
      )
  )

  # R_02: OR — capper_jam_sens == true OU liquid_lvl_detect == :fail OU collision_alert == true
  defrule(RegraIntertravamentoEnvase,
    watch: [:fbe_08_capper_jam_sens, :fbe_08_liquid_lvl_detect, :fbe_10_collision_alert],
    when:
      memoria[:fbe_08_capper_jam_sens] == true or memoria[:fbe_08_liquid_lvl_detect] == :fail or
        memoria[:fbe_10_collision_alert] == true,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_08.emergency_halt_conveyor()
        Tec0301Pon.Examples.SmartBrewery.FBE_10.recalculate_route_avoidance()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_02)
      )
  )

  # R_03: AND — internal_temp < Target+1, cip_pump_state == :on, grid_power_cost > PICO
  # Target = 18°C, PICO = 150 (limiar tarifa de pico)
  defrule(RegraSmartGridLoadBalancing,
    watch: [:fbe_06_internal_temp, :fbe_09_cip_pump_state, :fbe_11_grid_power_cost],
    when:
      memoria[:fbe_06_internal_temp] < 19 and memoria[:fbe_09_cip_pump_state] == :on and
        memoria[:fbe_11_grid_power_cost] > 150,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_06.pause_glycol_chilling()
        Tec0301Pon.Examples.SmartBrewery.FBE_11.discharge_v2g_buffer()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_03)
      )
  )

  # R_04 — Proteção Moinho (Artigo 11 §2, ISO 10816-3). Zona C: reduzir RPM; Zona D: fechar válvula.
  defrule(RegraProtecaoMoinho,
    watch: [
      :fbe_01_motor_temp,
      :fbe_01_vibration_level,
      :fbe_01_hopper_level,
      :fbe_01_motor_rpm,
      :fbe_01_feed_valve_state
    ],
    when:
      (memoria[:fbe_01_vibration_level] != nil and memoria[:fbe_01_vibration_level] > 80) or
        (memoria[:fbe_01_motor_temp] != nil and memoria[:fbe_01_motor_temp] > 70) or
        (memoria[:fbe_01_hopper_level] != nil and memoria[:fbe_01_motor_rpm] != nil and
           memoria[:fbe_01_hopper_level] < 15 and memoria[:fbe_01_motor_rpm] > 0),
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_01.reduce_motor_rpm()

        if memoria[:fbe_01_vibration_level] != nil and memoria[:fbe_01_vibration_level] > 95,
          do: Tec0301Pon.Examples.SmartBrewery.FBE_01.close_feed_valve()

        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_04)
      )
  )

  # R_05 — Controle Mostura (Artigo 11 §3). Temperatura/pH fora da faixa enzimática ou nível alto sem agitador.
  defrule(RegraControleMostura,
    watch: [:fbe_02_mash_temp, :fbe_02_ph_level, :fbe_02_liquid_level, :fbe_02_agitator_status],
    when:
      (memoria[:fbe_02_mash_temp] != nil and
         (memoria[:fbe_02_mash_temp] < 60 or memoria[:fbe_02_mash_temp] > 72)) or
        (memoria[:fbe_02_ph_level] != nil and
           (memoria[:fbe_02_ph_level] < 5.0 or memoria[:fbe_02_ph_level] > 5.8)) or
        (memoria[:fbe_02_liquid_level] != nil and memoria[:fbe_02_agitator_status] == :off and
           memoria[:fbe_02_liquid_level] > 90),
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_02.start_agitator()
        Tec0301Pon.Examples.SmartBrewery.FBE_02.adjust_water_flow(50)
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_05)
      )
  )

  # R_06 — Segurança Caldeira (Artigo 11 §4, NR-13). Boil-over, espuma ou pressão de vapor alta.
  defrule(RegraSegurancaCaldeira,
    watch: [
      :fbe_04_boil_temp,
      :fbe_04_steam_pressure,
      :fbe_04_foam_level,
      :fbe_04_hop_doser_state
    ],
    when:
      (memoria[:fbe_04_foam_level] != nil and memoria[:fbe_04_foam_level] > 85) or
        (memoria[:fbe_04_steam_pressure] != nil and memoria[:fbe_04_steam_pressure] > 4.0) or
        (memoria[:fbe_04_boil_temp] != nil and memoria[:fbe_04_boil_temp] > 103 and
           memoria[:fbe_04_hop_doser_state] != :idle),
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_04.pause_hop_doser()
        Tec0301Pon.Examples.SmartBrewery.FBE_04.reduce_steam_pressure()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_06)
      )
  )

  # R_07 — Otimização Trocador (Artigo 11 §5, LMTD). Saída mosto quente com margem na válvula de glicol.
  defrule(RegraOtimizacaoTrocador,
    watch: [:fbe_05_wort_in_temp, :fbe_05_wort_out_temp, :fbe_05_glycol_valve_pos],
    when:
      memoria[:fbe_05_wort_out_temp] != nil and memoria[:fbe_05_wort_out_temp] > 20 and
        memoria[:fbe_05_wort_in_temp] != nil and memoria[:fbe_05_wort_in_temp] > 80 and
        memoria[:fbe_05_glycol_valve_pos] != nil and memoria[:fbe_05_glycol_valve_pos] < 90,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_05.increase_glycol_valve()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_07)
      )
  )

  # R_08 — Load Balancing Fermentador B (Artigo 11 §8). Temp baixa, tarifa de pico, V2G disponível.
  defrule(RegraLoadBalancingFermentadorB,
    watch: [:fbe_07_internal_temp, :fbe_11_grid_power_cost, :fbe_11_v2g_battery_lvl],
    when:
      memoria[:fbe_07_internal_temp] != nil and memoria[:fbe_07_internal_temp] < 19 and
        memoria[:fbe_11_grid_power_cost] != nil and memoria[:fbe_11_grid_power_cost] > 150 and
        memoria[:fbe_11_v2g_battery_lvl] != nil and memoria[:fbe_11_v2g_battery_lvl] > 20,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_07.pause_glycol_chilling()
        Tec0301Pon.Examples.SmartBrewery.FBE_11.discharge_v2g_buffer()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_08)
      )
  )

  # R_09 — Intertravamento Mostura → Filtração (Artigo 11 §6, ISA-88). Bomba ligada com mostura não pronta.
  defrule(RegraIntertravamentoMosturaFiltro,
    watch: [:fbe_02_mash_temp, :fbe_02_liquid_level, :fbe_03_pump_speed],
    when:
      memoria[:fbe_03_pump_speed] != nil and memoria[:fbe_03_pump_speed] > 0 and
        ((memoria[:fbe_02_mash_temp] != nil and memoria[:fbe_02_mash_temp] < 65) or
           (memoria[:fbe_02_liquid_level] != nil and memoria[:fbe_02_liquid_level] < 50)),
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_03.zero_pump()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_09)
      )
  )

  # R_10 — Intertravamento Fervura → Trocador (Artigo 11 §6). Fervura ativa com válvula de glicol fechada.
  defrule(RegraIntertravamentoFervuraTrocador,
    watch: [:fbe_04_boil_temp, :fbe_05_glycol_valve_pos],
    when:
      memoria[:fbe_04_boil_temp] != nil and memoria[:fbe_04_boil_temp] > 95 and
        memoria[:fbe_05_glycol_valve_pos] != nil and memoria[:fbe_05_glycol_valve_pos] == 0,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_05.increase_glycol_valve()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_10)
      )
  )

  # R_11 — Gestão Bateria AMR (Artigo 11 §7). Bateria baixa com robô em missão.
  defrule(RegraGestaoBateriaAMR,
    watch: [:fbe_10_robot_1_battery, :fbe_10_robot_1_status],
    when:
      memoria[:fbe_10_robot_1_battery] != nil and memoria[:fbe_10_robot_1_battery] < 20 and
        memoria[:fbe_10_robot_1_status] != nil and memoria[:fbe_10_robot_1_status] != :ocioso,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_10.request_charge_station_return()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_11)
      )
  )

  # R_12 — Resiliência Rede (Artigo 11 §8). Falha de rede → modo ilha, load shedding, V2G.
  defrule(RegraResilienciaRede,
    watch: [:fbe_11_grid_fault_detec],
    when: memoria[:fbe_11_grid_fault_detec] == true,
    do:
      (
        Tec0301Pon.Examples.SmartBrewery.FBE_11.enable_island_mode()
        Tec0301Pon.Examples.SmartBrewery.FBE_11.shed_non_critical_load()
        Tec0301Pon.Examples.SmartBrewery.FBE_11.discharge_v2g_buffer()
        Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_12)
      )
  )
end
