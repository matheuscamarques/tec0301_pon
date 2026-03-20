defmodule Tec0301Pon.ExamplesCoverageTest do
  use Tec0301Pon.PonCase

  import ExUnit.CaptureIO

  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.Examples

  defp stop_named(name) when is_atom(name) do
    case Process.whereis(name) do
      nil ->
        :ok

      pid ->
        Process.exit(pid, :kill)
        Process.sleep(5)
    end
  end

  defp reset_facts(names) when is_list(names) do
    Enum.each(names, &stop_named/1)
  end

  test "adapters return :ok and emit expected IO" do
    out =
      capture_io(fn ->
        assert :ok == Tec0301Pon.Adapters.AlarmeIO.disparar("teste")
        assert :ok == Tec0301Pon.Adapters.BombaDeAgua.ligar()
        assert :ok == Tec0301Pon.Adapters.BombaDeAgua.desligar()
        assert :ok == Tec0301Pon.Adapters.PortaoIO.abrir()
        assert :ok == Tec0301Pon.Adapters.PortaoIO.fechar()
        assert :ok == Tec0301Pon.Adapters.PredioIO.ligar_luz()
        assert :ok == Tec0301Pon.Adapters.PredioIO.desligar_luz()
        assert :ok == Tec0301Pon.Adapters.PredioIO.ligar_ar()
        assert :ok == Tec0301Pon.Adapters.PredioIO.ventilar()
        assert :ok == Tec0301Pon.Adapters.PredioIO.trancar_porta()
      end)

    assert out =~ "ALARME CRÍTICO"
    assert out =~ "Bomba LIGADA"
    assert out =~ "ABRINDO"
    assert out =~ "Iluminação: Luz LIGADA"
  end

  test "example modules start and simulate basic flows" do
    reset_facts([
      :alarme_ligado,
      :sensor_anomalia,
      :alarme_corr_sensor_temp,
      :alarme_corr_sensor_presenca,
      :alarme_corr_sistema_ativo,
      :temp_ambiente,
      :umidade_solo,
      :nivel_tanque,
      :estado_bomba,
      :mira_alvo_detectado,
      :mira_alinhada,
      :portao_comando_abrir,
      :portao_sensor_obstaculo,
      :portao_aberto,
      :predio_temp_sala,
      :predio_ocupacao_sala,
      :predio_hora_noturna,
      :predio_alarme_incendio,
      :predio_porta_aberta,
      :predio_co2_alto,
      :predio_luz_sala_ligada,
      :predio_modo_emergencia,
      :vendas_estoque,
      :vendas_cliente_valido,
      :vendas_tipo_desconto,
      :vendas_quantidade_pedido
    ])

    assert {:ok, _} = Examples.AlarmeSimples.start_link()
    assert {:ok, _} = Examples.AlarmeCorrelacao.start_link()
    assert {:ok, _} = Examples.Estufa.start_link()
    assert {:ok, _} = Examples.MiraAlvo.start_link()
    assert {:ok, _} = Examples.PortaoEletronico.start_link()
    assert {:ok, _} = Examples.PredioInteligente.start_link()
    assert {:ok, _} = Examples.Vendas.start_link()

    _ = capture_io(fn -> Examples.AlarmeSimples.simular() end)
    _ = capture_io(fn -> Examples.AlarmeCorrelacao.simular() end)
    _ = capture_io(fn -> Examples.Estufa.simular() end)
    _ = capture_io(fn -> Examples.MiraAlvo.simular() end)
    _ = capture_io(fn -> Examples.PortaoEletronico.simular() end)
    _ = capture_io(fn -> Examples.PredioInteligente.simular() end)
    _ = capture_io(fn -> Examples.Vendas.simular() end)

    assert Fato.obter(:sensor_anomalia) == true
    assert Fato.obter(:alarme_corr_sistema_ativo) == true
    assert Fato.obter(:portao_aberto) == true
    assert Fato.obter(:mira_alinhada) == true
    assert Fato.obter(:vendas_tipo_desconto) == :vip
  end

  test "smart brewery rules and FBE actions are exercised" do
    reset_facts(Examples.SmartBrewery.fatos_names())
    stop_named(:smart_brewery_regra_notifier)

    parent = self()

    forwarder =
      spawn(fn ->
        receive_loop = fn loop ->
          receive do
            msg ->
              send(parent, msg)
              loop.(loop)
          end
        end

        receive_loop.(receive_loop)
      end)

    if Process.whereis(:smart_brewery_regra_notifier) == nil do
      Process.register(forwarder, :smart_brewery_regra_notifier)
    else
      Process.exit(forwarder, :normal)
    end

    assert {:ok, _} = Examples.SmartBrewery.start_link()
    assert is_list(Examples.SmartBrewery.fatos_names())
    _ = capture_io(fn -> Examples.SmartBrewery.simular() end)

    # R_04
    Fato.atualizar(:fbe_01_motor_rpm, 1200)
    Fato.atualizar(:fbe_01_vibration_level, 96)

    # R_05
    Fato.atualizar(:fbe_02_mash_temp, 55)

    # R_06
    Fato.atualizar(:fbe_04_hop_doser_state, :dosando)
    Fato.atualizar(:fbe_04_foam_level, 90)

    # R_07
    Fato.atualizar(:fbe_05_wort_in_temp, 90)
    Fato.atualizar(:fbe_05_wort_out_temp, 30)
    Fato.atualizar(:fbe_05_glycol_valve_pos, 0)

    # R_08
    Fato.atualizar(:fbe_07_internal_temp, 18)
    Fato.atualizar(:fbe_11_grid_power_cost, 200)
    Fato.atualizar(:fbe_11_v2g_battery_lvl, 80)

    # R_09
    Fato.atualizar(:fbe_03_pump_speed, 20)
    Fato.atualizar(:fbe_02_mash_temp, 60)

    # R_10
    Fato.atualizar(:fbe_04_boil_temp, 100)
    Fato.atualizar(:fbe_05_glycol_valve_pos, 0)

    # R_11
    Fato.atualizar(:fbe_10_robot_1_status, :transportando)
    Fato.atualizar(:fbe_10_robot_1_battery, 10)

    # R_12
    Fato.atualizar(:fbe_11_main_load_draw, 70)
    Fato.atualizar(:fbe_11_grid_fault_detec, true)

    # Chamada direta das ações FBE para cobrir caminhos utilitários.
    Tec0301Pon.Examples.SmartBrewery.FBE_02.start_agitator()
    Tec0301Pon.Examples.SmartBrewery.FBE_02.adjust_water_flow(120)
    Tec0301Pon.Examples.SmartBrewery.FBE_04.pause_hop_doser()
    Tec0301Pon.Examples.SmartBrewery.FBE_04.reduce_steam_pressure()
    Tec0301Pon.Examples.SmartBrewery.FBE_05.increase_glycol_valve()
    Tec0301Pon.Examples.SmartBrewery.FBE_06.pause_glycol_chilling()
    Tec0301Pon.Examples.SmartBrewery.FBE_07.pause_glycol_chilling()
    Tec0301Pon.Examples.SmartBrewery.FBE_08.emergency_halt_conveyor()
    Tec0301Pon.Examples.SmartBrewery.FBE_10.recalculate_route_avoidance()
    Tec0301Pon.Examples.SmartBrewery.FBE_10.request_charge_station_return()
    Tec0301Pon.Examples.SmartBrewery.FBE_11.enable_island_mode()
    Tec0301Pon.Examples.SmartBrewery.FBE_11.shed_non_critical_load()

    Process.sleep(250)

    assert Fato.obter(:fbe_01_feed_valve_state) == :closed
    assert Fato.obter(:fbe_02_agitator_status) == :on
    assert Fato.obter(:fbe_02_water_flow_rate) in [50, 100]
    assert Fato.obter(:fbe_03_pump_speed) == 0
    assert Fato.obter(:fbe_04_hop_doser_state) == :idle
    assert Fato.obter(:fbe_06_glycol_jacket_st) == :off
    assert Fato.obter(:fbe_07_glycol_jacket_st) == :off
    assert Fato.obter(:fbe_08_conveyor_speed) == 0
    assert Fato.obter(:fbe_10_robot_1_status) in [:recalculando_rota, :retornando_estacao]
    assert Fato.obter(:fbe_11_main_load_draw) <= 70

    assert_receive {:regra_disparada, _}, 1_000

    stop_named(:smart_brewery_regra_notifier)
    assert :ok == Tec0301Pon.Examples.SmartBrewery.RegraNotifier.notify(:r_01)
  end

  test "direct execution of example rule modules covers remaining branches" do
    reset_facts([
      :estado_bomba,
      :fbe_03_pump_speed,
      :fbe_03_rake_height,
      :fbe_05_glycol_valve_pos,
      :fbe_04_steam_pressure,
      :fbe_01_motor_rpm,
      :fbe_01_feed_valve_state
    ])

    {:ok, _} = Fato.start_link(:estado_bomba, :ligada)
    {:ok, _} = Fato.start_link(:fbe_03_pump_speed, 30)
    {:ok, _} = Fato.start_link(:fbe_03_rake_height, 10)
    {:ok, _} = Fato.start_link(:fbe_05_glycol_valve_pos, 95)
    {:ok, _} = Fato.start_link(:fbe_04_steam_pressure, 5.0)
    {:ok, _} = Fato.start_link(:fbe_01_motor_rpm, 800)
    {:ok, _} = Fato.start_link(:fbe_01_feed_valve_state, :open)

    # Estufa.RegraParada
    assert Tec0301Pon.Examples.Estufa.Regras.RegraParada.avaliar(%{
             umidade_solo: 60,
             estado_bomba: :ligada
           })

    _ =
      capture_io(fn ->
        Tec0301Pon.Examples.Estufa.Regras.RegraParada.executar(%{
          umidade_solo: 60,
          estado_bomba: :ligada
        })
      end)

    # Prédio Inteligente regras com baixa cobertura
    refute Tec0301Pon.Examples.PredioInteligente.Regras.RegraSairEmergencia.avaliar(%{
             predio_alarme_incendio: false
           })

    _ =
      capture_io(fn ->
        Tec0301Pon.Examples.PredioInteligente.Regras.RegraSairEmergencia.executar(%{
          predio_alarme_incendio: false
        })

        Tec0301Pon.Examples.PredioInteligente.Regras.RegraLuzOff.executar(%{
          predio_ocupacao_sala: false,
          predio_hora_noturna: true,
          predio_luz_sala_ligada: true
        })

        Tec0301Pon.Examples.PredioInteligente.Regras.RegraLuzOn.executar(%{
          predio_ocupacao_sala: true,
          predio_hora_noturna: true,
          predio_luz_sala_ligada: false
        })

        Tec0301Pon.Examples.PredioInteligente.Regras.RegraLigarAr.executar(%{
          predio_temp_sala: 30,
          predio_ocupacao_sala: true,
          predio_modo_emergencia: false
        })

        Tec0301Pon.Examples.PredioInteligente.Regras.RegraVentilarCO2.executar(%{
          predio_co2_alto: true,
          predio_modo_emergencia: false
        })
      end)

    # SmartBrewery FBE helpers e regras restantes
    Tec0301Pon.Examples.SmartBrewery.FBE_03.reduce_pump_10pct()
    Tec0301Pon.Examples.SmartBrewery.FBE_03.zero_pump()
    Tec0301Pon.Examples.SmartBrewery.FBE_03.lower_rake_position()
    Fato.atualizar(:fbe_05_glycol_valve_pos, 50)
    Tec0301Pon.Examples.SmartBrewery.FBE_05.increase_glycol_valve()
    Fato.atualizar(:fbe_05_glycol_valve_pos, 95)
    Tec0301Pon.Examples.SmartBrewery.FBE_05.increase_glycol_valve()

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraOtimizacaoFiltracao.avaliar(%{
             fbe_03_diff_pressure: 151,
             fbe_03_wort_clarity: 10,
             fbe_03_pump_speed: 60
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoEnvase.avaliar(%{
             fbe_08_capper_jam_sens: false,
             fbe_08_liquid_lvl_detect: :fail,
             fbe_10_collision_alert: false
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoEnvase.avaliar(%{
             fbe_08_capper_jam_sens: true,
             fbe_08_liquid_lvl_detect: :ok,
             fbe_10_collision_alert: false
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoEnvase.avaliar(%{
             fbe_08_capper_jam_sens: false,
             fbe_08_liquid_lvl_detect: :ok,
             fbe_10_collision_alert: true
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraControleMostura.avaliar(%{
             fbe_02_mash_temp: 59,
             fbe_02_ph_level: 5.2,
             fbe_02_liquid_level: 10,
             fbe_02_agitator_status: :off
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.mostura_fora_faixa?(%{
             fbe_02_mash_temp: 59,
             fbe_02_ph_level: 5.2,
             fbe_02_liquid_level: 10,
             fbe_02_agitator_status: :off
           })

    refute Tec0301Pon.Examples.SmartBrewery.Regras.mostura_fora_faixa?(%{
             fbe_02_mash_temp: 66,
             fbe_02_ph_level: 5.2,
             fbe_02_liquid_level: 50,
             fbe_02_agitator_status: :on
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraControleMostura.avaliar(%{
             fbe_02_mash_temp: 66,
             fbe_02_ph_level: 4.9,
             fbe_02_liquid_level: 10,
             fbe_02_agitator_status: :off
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraControleMostura.avaliar(%{
             fbe_02_mash_temp: 66,
             fbe_02_ph_level: 5.2,
             fbe_02_liquid_level: 95,
             fbe_02_agitator_status: :off
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraSegurancaCaldeira.avaliar(%{
             fbe_04_foam_level: 86,
             fbe_04_steam_pressure: 3.0,
             fbe_04_boil_temp: 100,
             fbe_04_hop_doser_state: :dosando
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraSegurancaCaldeira.avaliar(%{
             fbe_04_foam_level: 10,
             fbe_04_steam_pressure: 4.2,
             fbe_04_boil_temp: 100,
             fbe_04_hop_doser_state: :dosando
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraSegurancaCaldeira.avaliar(%{
             fbe_04_foam_level: 10,
             fbe_04_steam_pressure: 2.0,
             fbe_04_boil_temp: 104,
             fbe_04_hop_doser_state: :dosando
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraProtecaoMoinho.avaliar(%{
             fbe_01_vibration_level: 96,
             fbe_01_motor_temp: 50,
             fbe_01_hopper_level: 50,
             fbe_01_motor_rpm: 800
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraProtecaoMoinho.avaliar(%{
             fbe_01_vibration_level: 50,
             fbe_01_motor_temp: 71,
             fbe_01_hopper_level: 50,
             fbe_01_motor_rpm: 800
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraProtecaoMoinho.avaliar(%{
             fbe_01_vibration_level: 50,
             fbe_01_motor_temp: 40,
             fbe_01_hopper_level: 10,
             fbe_01_motor_rpm: 500
           })

    assert Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoFervuraTrocador.avaliar(%{
             fbe_04_boil_temp: 96,
             fbe_05_glycol_valve_pos: 0
           })

    refute Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoFervuraTrocador.avaliar(%{
             fbe_04_boil_temp: 80,
             fbe_05_glycol_valve_pos: 50
           })

    assert Tec0301Pon.Examples.PredioInteligente.Regras.RegraLuzOff.avaliar(%{
             predio_ocupacao_sala: false,
             predio_hora_noturna: true,
             predio_luz_sala_ligada: true
           })

    refute Tec0301Pon.Examples.PredioInteligente.Regras.RegraLuzOff.avaliar(%{
             predio_ocupacao_sala: true,
             predio_hora_noturna: true,
             predio_luz_sala_ligada: true
           })

    _ =
      capture_io(fn ->
        Tec0301Pon.Examples.SmartBrewery.Regras.RegraOtimizacaoFiltracao.executar(%{})
        Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoEnvase.executar(%{})
        Tec0301Pon.Examples.SmartBrewery.Regras.RegraControleMostura.executar(%{})
        Tec0301Pon.Examples.SmartBrewery.Regras.RegraSegurancaCaldeira.executar(%{})
        Tec0301Pon.Examples.SmartBrewery.Regras.RegraIntertravamentoFervuraTrocador.executar(%{})

        Tec0301Pon.Examples.SmartBrewery.Regras.RegraProtecaoMoinho.executar(%{
          fbe_01_vibration_level: 96
        })

        Tec0301Pon.Examples.SmartBrewery.Regras.RegraProtecaoMoinho.executar(%{
          fbe_01_vibration_level: 90
        })
      end)

    assert is_pid(Process.whereis(:fbe_03_pump_speed))
    assert Fato.obter(:fbe_05_glycol_valve_pos) <= 100
  end
end
