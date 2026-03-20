defmodule SimulacoesVisuais.Repo.Migrations.PowerBiDimContext do
  @moduledoc """
  Contexto para relatórios Power BI: texto longo por variável (`descricao_longa`, alinhado a
  `FatoDescriptions`) e dimensão `dim_regras` para `rule_events.regra_id` (r_01..r_12).
  """
  use Ecto.Migration

  def up do
    alter table(:dim_variaveis_mapeamento) do
      add :descricao_longa, :text
    end

    create table(:dim_regras, primary_key: false) do
      add :regra_id, :string, primary_key: true
      add :nome, :string, null: false
      add :descricao_curta, :text
      add :descricao_longa, :text
    end

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powerbi_analytics') THEN
        EXECUTE 'GRANT SELECT ON TABLE dim_regras TO powerbi_analytics';
      END IF;
    END $$;
    """

    # Aplica DDL acima antes de consultas parametrizadas (compatível sem `run/1` do Ecto.Migration).
    flush()

    repo = SimulacoesVisuais.Repo
    alias SimulacoesVisuais.SmartBrewery.FatoDescriptions

    Enum.each(Tec0301Pon.Examples.SmartBrewery.fatos_names(), fn atom ->
      desc = FatoDescriptions.descricao(atom)

      if desc != "" do
        fact = Atom.to_string(atom)

        Ecto.Adapters.SQL.query!(
          repo,
          "UPDATE dim_variaveis_mapeamento SET descricao_longa = $1 WHERE fact_name = $2",
          [desc, fact]
        )
      end
    end)

    Enum.each(regras_seed_rows(), fn {id, nome, curta, longa} ->
      Ecto.Adapters.SQL.query!(
        repo,
        """
        INSERT INTO dim_regras (regra_id, nome, descricao_curta, descricao_longa)
        VALUES ($1,$2,$3,$4)
        """,
        [id, nome, curta, longa]
      )
    end)
  end

  def down do
    drop table(:dim_regras)

    alter table(:dim_variaveis_mapeamento) do
      remove :descricao_longa
    end
  end

  defp regras_seed_rows do
    [
      {"r_01", "Otimização Filtração", "diff_pressure, wort_clarity, pump_speed → FBE_03",
       "Otimiza a filtração e previne cavitação. Observa os atributos diff_pressure, wort_clarity e pump_speed do FBE_03. Dispara quando os três estão simultaneamente fora da faixa (pressão > 150 mbar, turbidez < 20 NTU, bomba > 50%). A ação instiga no FBE_03: reduzir bomba em 10% e baixar as facas. A regra só é avaliada quando algum desses atributos notifica uma mudança; então as premissas e a condição AND são reavaliadas e, se verdadeiras, a ação executa."},
      {"r_02", "Intertravamento Envase",
       "capper_jam, liquid_lvl, collision → FBE_08, FBE_10",
       "Intertravamento crítico da linha de envase. Observa capper_jam_sens (FBE_08), liquid_lvl_detect (FBE_08) e collision_alert (FBE_10). Dispara se qualquer um indicar falha: encravamento na arrolhadora, nível de líquido com falha ou alerta de colisão do AMR. Ação: parada de emergência da esteira (FBE_08) e recálculo de rota de evitação (FBE_10). É acionada pontualmente quando um desses fatos notifica mudança e a condição OR fica verdadeira."},
      {"r_03", "Smart Grid", "internal_temp, cip_pump, grid_power → FBE_06, FBE_11",
       "Gestão de demanda energética (Smart Grid). Observa temperatura interna do fermentador A (FBE_06), estado da bomba CIP (FBE_09) e custo da tarifa (FBE_11). Dispara quando fermentação está estável (< 19°C), CIP ligado e tarifa em pico (> 150). Ação: pausar resfriamento por glicol no FBE_06 e descarregar buffer V2G no FBE_11. A regra é acionada apenas quando algum dos três atributos notifica; a condição AND é então reavaliada."},
      {"r_04", "Proteção Moinho", "vibração, motor_temp, hopper → FBE_01 (ISO 10816-3)",
       "Proteção do moinho (ISO 10816-3). Observa temperatura do motor, vibração, nível do funil, RPM e estado da válvula de alimentação (FBE_01). Dispara se vibração > 80, ou motor > 70°C, ou funil baixo com motor ligado. Ação: reduzir RPM; se vibração > 95, fechar válvula de alimentação. A regra só reage quando um desses fatos notifica; evita desgaste e cavitação."},
      {"r_05", "Controle Mostura", "mash_temp, pH, liquid_level, agitator → FBE_02",
       "Controle da mostura. Observa temperatura do mosto, pH, nível de líquido e status do agitador (FBE_02). Dispara se temperatura fora da faixa enzimática (60–72°C), ou pH fora de 5,0–5,8, ou nível alto com agitador desligado. Ação: ligar agitador e ajustar vazão de água. Acionada quando qualquer um desses atributos notifica e a condição fica verdadeira."},
      {"r_06", "Segurança Caldeira", "foam, steam_pressure, boil_temp → FBE_04 (NR-13)",
       "Segurança da caldeira (NR-13). Observa espuma, pressão de vapor, temperatura de ebulição e estado do dosador de lúpulo (FBE_04). Dispara se espuma alta, pressão > 4 bar ou fervura > 103°C com dosador ativo. Ação: pausar dosador de lúpulo e reduzir pressão de vapor. A regra é avaliada somente quando um desses atributos notifica mudança."},
      {"r_07", "Otimização Trocador", "wort_in/out_temp, glycol_valve → FBE_05 (LMTD)",
       "Otimização do trocador de calor (LMTD). Observa temperaturas de entrada e saída do mosto e posição da válvula de glicol (FBE_05). Dispara quando mosto quente na entrada (> 80°C), saída ainda quente (> 20°C) e válvula com margem (< 90%). Ação: aumentar abertura da válvula de glicol. Acionada pontualmente quando um dos fatos observados notifica."},
      {"r_08", "Load Balancing Ferm. B", "internal_temp, grid_power_cost, v2g → FBE_07, FBE_11",
       "Load balancing do fermentador B. Observa temperatura interna (FBE_07), custo da tarifa e nível V2G (FBE_11). Dispara quando fermentação estável (< 19°C), tarifa em pico e bateria V2G disponível (> 20%). Ação: pausar resfriamento no FBE_07 e descarregar buffer V2G no FBE_11. A regra é acionada quando algum desses atributos notifica e a condição AND é satisfeita."},
      {"r_09", "Intertrav. Mostura→Filtro", "mash_temp, liquid_level, pump_speed → FBE_03 (ISA-88)",
       "Intertravamento Mostura → Filtro (ISA-88). Observa temperatura e nível do mostura (FBE_02) e velocidade da bomba (FBE_03). Dispara se a bomba estiver ligada com mostura não pronta (temperatura < 65°C ou nível < 50%). Ação: zerar a bomba no FBE_03. Garante que o mosto só seja transferido quando a mostura estiver no ponto; acionada quando um dos fatos notifica."},
      {"r_10", "Intertrav. Fervura→Trocador", "boil_temp, glycol_valve_pos → FBE_05",
       "Intertravamento Fervura → Trocador. Observa temperatura da caldeira (FBE_04) e posição da válvula de glicol (FBE_05). Dispara quando fervura ativa (> 95°C) e válvula de glicol fechada (0). Ação: aumentar abertura da válvula no FBE_05 para evitar receber mosto quente sem capacidade de resfriamento. Acionada quando um dos dois atributos notifica."},
      {"r_11", "Gestão Bateria AMR", "robot_battery, robot_status → FBE_10",
       "Gestão da bateria dos AMRs. Observa nível de bateria e status do robô (FBE_10). Dispara quando bateria < 20% e robô não está ocioso (em missão ou carregando). Ação: solicitar retorno à estação de carregamento. A regra é acionada quando bateria ou status notificam mudança, evitando que o robô pare longe do carregador."},
      {"r_12", "Resiliência Rede", "grid_fault_detec → FBE_11 (modo ilha, load shedding)",
       "Resiliência da rede. Observa apenas grid_fault_detec (FBE_11). Dispara quando há falha detectada na rede (true). Ação: ativar modo ilha, fazer load shedding de cargas não críticas e descarregar buffer V2G. A regra é acionada exclusivamente quando o atributo de falha notifica a mudança, permitindo resposta imediata à queda de energia."}
    ]
  end
end
