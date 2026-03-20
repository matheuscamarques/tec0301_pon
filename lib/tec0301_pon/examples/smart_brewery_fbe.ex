defmodule Tec0301Pon.Examples.SmartBrewery.FBE_01 do
  @moduledoc """
  Moinho de Malte. Instigações: reduzir RPM e fechar válvula de alimentação (R_04 — Artigo 11).
  Base: ISO 10816-3 (zonas vibração), temperatura carcaça.
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def reduce_motor_rpm do
    current = Fato.obter(:fbe_01_motor_rpm)
    novo = max(0, current - 300)
    Fato.atualizar(:fbe_01_motor_rpm, novo)
    Logger.debug("[FBE_01] R_04: reduce_motor_rpm — motor_rpm #{current} → #{novo}")
  end

  def close_feed_valve do
    Fato.atualizar(:fbe_01_feed_valve_state, :closed)
    Logger.info("[FBE_01] R_04: close_feed_valve — feed_valve_state → :closed")
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_02 do
  @moduledoc """
  Tanque Mostura. Instigações: ligar agitador e ajustar vazão de água (R_05 — Artigo 11).
  Base: janelas enzimáticas alfa/beta amilase, pH 5.0–5.8.
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def start_agitator do
    Fato.atualizar(:fbe_02_agitator_status, :on)
    Logger.info("[FBE_02] R_05: start_agitator — agitator_status → :on")
  end

  def adjust_water_flow(setpoint) when is_number(setpoint) do
    Fato.atualizar(:fbe_02_water_flow_rate, max(0, min(100, setpoint)))
    Logger.info("[FBE_02] R_05: adjust_water_flow — water_flow_rate → #{setpoint}")
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_03 do
  @moduledoc """
  Tina de Filtro (Lautering). Instigações: reduzir bomba 10%, baixar posição do rake
  para prevenção de cavitação (R_01 — Artigo 05); zero_pump para intertravamento R_09 (ISA-88).
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def reduce_pump_10pct do
    current = Fato.obter(:fbe_03_pump_speed)
    novo = max(0, current - 10)
    Fato.atualizar(:fbe_03_pump_speed, novo)
    Logger.info("[FBE_03] AC_01: reduce_pump_10pct — pump_speed #{current} → #{novo}%")
  end

  def zero_pump do
    Fato.atualizar(:fbe_03_pump_speed, 0)
    Logger.info("[FBE_03] R_09: zero_pump — pump_speed → 0 (intertravamento mostura→filtração)")
  end

  def lower_rake_position do
    current = Fato.obter(:fbe_03_rake_height)
    novo = max(0, current - 5)
    Fato.atualizar(:fbe_03_rake_height, novo)
    Logger.info("[FBE_03] AC_01: lower_rake_position — rake_height #{current} → #{novo}")
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_04 do
  @moduledoc """
  Caldeira de Fervura. Instigações: pausar dosador de lúpulo e modular vapor (R_06 — Artigo 11).
  Base: NR-13, prevenção boil-over, modulação (não corte brusco).
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def pause_hop_doser do
    Fato.atualizar(:fbe_04_hop_doser_state, :idle)
    Logger.info("[FBE_04] R_06: pause_hop_doser — hop_doser_state → :idle")
  end

  def reduce_steam_pressure do
    current = Fato.obter(:fbe_04_steam_pressure)
    novo = max(0, current - 0.5)
    Fato.atualizar(:fbe_04_steam_pressure, novo)
    Logger.info("[FBE_04] R_06: reduce_steam_pressure — steam_pressure #{current} → #{novo}")
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_05 do
  @moduledoc """
  Trocador de Calor (PHE). Instigação: aumentar abertura da válvula de glicol (R_07, R_10 — Artigo 11).
  Base: LMTD, resfriamento mosto até setpoint.
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def increase_glycol_valve do
    current = Fato.obter(:fbe_05_glycol_valve_pos)
    novo = min(100, current + 10)
    Fato.atualizar(:fbe_05_glycol_valve_pos, novo)
    msg = "[FBE_05] R_07/R_10: increase_glycol_valve — glycol_valve_pos #{current} → #{novo}%"
    Logger.info(msg)
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_06 do
  @moduledoc """
  Fermentador A. Instigação: pausar refrigeração por jaqueta de glicol (R_03).
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def pause_glycol_chilling do
    Fato.atualizar(:fbe_06_glycol_jacket_st, :off)
    Logger.info("[FBE_06] AC_03: pause_glycol_chilling — glycol_jacket_st → :off")
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_07 do
  @moduledoc """
  Fermentador B. Instigação: pausar refrigeração por glicol (R_08 — Artigo 11, load balancing).
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def pause_glycol_chilling do
    Fato.atualizar(:fbe_07_glycol_jacket_st, :off)
    Logger.info("[FBE_07] R_08: pause_glycol_chilling — glycol_jacket_st → :off")
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_08 do
  @moduledoc """
  Linha de Envase. Instigação: parada de emergência da esteira (R_02).
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def emergency_halt_conveyor do
    Fato.atualizar(:fbe_08_conveyor_speed, 0)
    Logger.info("[FBE_08] AC_02: emergency_halt_conveyor — conveyor_speed → 0")
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_10 do
  @moduledoc """
  Frota AMR. Instigações: recalcular rota de evasão (R_02); retorno à estação por bateria baixa (R_11).
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  def recalculate_route_avoidance do
    Fato.atualizar(:fbe_10_robot_1_status, :recalculando_rota)

    Logger.info(
      "[FBE_10] AC_02: recalculate_route_avoidance — robot_1_status → :recalculando_rota"
    )
  end

  def request_charge_station_return do
    Fato.atualizar(:fbe_10_robot_1_status, :retornando_estacao)

    Logger.info(
      "[FBE_10] R_11: request_charge_station_return — robot_1_status → :retornando_estacao"
    )
  end
end

defmodule Tec0301Pon.Examples.SmartBrewery.FBE_11 do
  @moduledoc """
  Smart Grid. Instigações: descarregar buffer V2G (R_03, R_08, R_12); modo ilha e load shedding (R_12).
  """
  require Logger
  alias Tec0301Pon.PON.Fato

  # Shallow cycling (artigo 12): não descarrega abaixo do piso de SoC para preservar SOH
  @soc_floor 20
  @discharge_delta 15

  def discharge_v2g_buffer do
    current = Fato.obter(:fbe_11_v2g_battery_lvl)
    current = if is_number(current), do: current, else: 80
    novo = max(@soc_floor, current - @discharge_delta)
    Fato.atualizar(:fbe_11_v2g_battery_lvl, novo)
    Logger.info("[FBE_11] AC_03: discharge_v2g_buffer — v2g_battery_lvl #{current} → #{novo}")
  end

  def enable_island_mode do
    # Sinaliza transição para modo ilha (microgrid isolada); carga crítica suprida por V2G
    Logger.info("[FBE_11] R_12: enable_island_mode — transição para operação em modo ilha")
  end

  def shed_non_critical_load do
    current = Fato.obter(:fbe_11_main_load_draw)
    novo = max(0, current - 30)
    Fato.atualizar(:fbe_11_main_load_draw, novo)
    Logger.info("[FBE_11] R_12: shed_non_critical_load — main_load_draw #{current} → #{novo}")
  end
end
