defmodule SimulacoesVisuais.Repo.Migrations.AddStarSchemaDimensionsAndFactViews do
  @moduledoc """
  Artigo 14: Star Schema para Power BI — tabelas de dimensão e views de fato.
  Relacionamentos 1:N entre fato e dimensões (ts_bucket, fact_name).
  """
  use Ecto.Migration

  def up do
    execute "SET search_path TO public;"

    # Dimensão Equipamento FBE: chave fbe_id, nome legível, fase operacional
    create table(:dim_equipamento_fbe, primary_key: false) do
      add :fbe_id, :string, primary_key: true
      add :nome, :string, null: false
      add :fase_operacional, :string
    end

    execute """
    INSERT INTO dim_equipamento_fbe (fbe_id, nome, fase_operacional) VALUES
      ('FBE_01', 'Moinho de Malte', 'Moagem'),
      ('FBE_02', 'Tanque de Mostura', 'Brassagem'),
      ('FBE_03', 'Tina de Filtro', 'Brassagem'),
      ('FBE_04', 'Caldeira de Fervura', 'Fervura'),
      ('FBE_05', 'Trocador de Calor', 'Resfriamento'),
      ('FBE_06', 'Fermentador A', 'Fermentação'),
      ('FBE_07', 'Fermentador B', 'Fermentação'),
      ('FBE_08', 'Linha de Envase', 'Envase'),
      ('FBE_09', 'Sistema CIP', 'CIP'),
      ('FBE_10', 'Frota AMR', 'Logística'),
      ('FBE_11', 'Smart Grid', 'Energia');
    """

    # Dimensão Variáveis: fact_name -> descrição e unidade (user-friendly para BI)
    create table(:dim_variaveis_mapeamento, primary_key: false) do
      add :fact_name, :string, primary_key: true
      add :descricao, :string, null: false
      add :unidade, :string
    end

    execute """
    INSERT INTO dim_variaveis_mapeamento (fact_name, descricao, unidade) VALUES
      ('fbe_01_motor_rpm', 'Velocidade do Moinho', 'RPM'),
      ('fbe_01_vibration_level', 'Nível de Vibração Moinho', 'mm/s'),
      ('fbe_01_hopper_level', 'Nível da Tremonha', '%'),
      ('fbe_01_motor_temp', 'Temperatura do Motor', '°C'),
      ('fbe_01_feed_valve_state', 'Estado da Válvula de Alimentação', null),
      ('fbe_02_mash_temp', 'Temperatura do Mosto', '°C'),
      ('fbe_02_water_flow_rate', 'Vazão de Água', 'L/min'),
      ('fbe_02_agitator_status', 'Status do Agitador', null),
      ('fbe_02_ph_level', 'pH do Mosto', 'pH'),
      ('fbe_02_viscosity', 'Viscosidade', 'cP'),
      ('fbe_02_liquid_level', 'Nível do Líquido', '%'),
      ('fbe_03_diff_pressure', 'Pressão Diferencial Filtro', 'mbar'),
      ('fbe_03_wort_clarity', 'Claridade do Mosto', '%'),
      ('fbe_03_sparge_water_temp', 'Temperatura Água de Lavagem', '°C'),
      ('fbe_03_rake_height', 'Altura do Rake', '%'),
      ('fbe_03_pump_speed', 'Velocidade da Bomba', '%'),
      ('fbe_04_boil_temp', 'Temperatura de Fervura', '°C'),
      ('fbe_04_steam_pressure', 'Pressão do Vapor', 'Bar'),
      ('fbe_04_evaporation_rate', 'Taxa de Evaporação', '%'),
      ('fbe_04_hop_doser_state', 'Estado do Dosador de Lúpulo', null),
      ('fbe_04_foam_level', 'Nível de Espuma', '%'),
      ('fbe_05_wort_in_temp', 'Temperatura Entrada Mosto', '°C'),
      ('fbe_05_wort_out_temp', 'Temperatura Saída Mosto', '°C'),
      ('fbe_05_glycol_valve_pos', 'Posição Válvula Glicol', '%'),
      ('fbe_05_water_pressure', 'Pressão da Água', 'Bar'),
      ('fbe_06_internal_temp', 'Temperatura Interna Fermentador A', '°C'),
      ('fbe_06_pressure', 'Pressão Fermentador A', 'Bar'),
      ('fbe_06_gravity_brix', 'Brix Fermentador A', 'Brix'),
      ('fbe_06_glycol_jacket_st', 'Status Jaqueta Glicol A', null),
      ('fbe_06_co2_exhaust_flow', 'Vazão CO2 Fermentador A', 'L/min'),
      ('fbe_06_ferm_phase', 'Fase Fermentação A', null),
      ('fbe_06_ph', 'pH Fermentador A', 'pH'),
      ('fbe_07_internal_temp', 'Temperatura Interna Fermentador B', '°C'),
      ('fbe_07_pressure', 'Pressão Fermentador B', 'Bar'),
      ('fbe_07_gravity_brix', 'Brix Fermentador B', 'Brix'),
      ('fbe_07_glycol_jacket_st', 'Status Jaqueta Glicol B', null),
      ('fbe_07_co2_exhaust_flow', 'Vazão CO2 Fermentador B', 'L/min'),
      ('fbe_07_ferm_phase', 'Fase Fermentação B', null),
      ('fbe_08_ir_bottle_detect', 'Detecção de Garrafa IR', null),
      ('fbe_08_conveyor_speed', 'Velocidade da Esteira', '%'),
      ('fbe_08_fill_head_status', 'Status Cabeça de Enchimento', null),
      ('fbe_08_liquid_lvl_detect', 'Detecção Nível Líquido', null),
      ('fbe_08_capper_jam_sens', 'Sensor de Atolamento Tampa', null),
      ('fbe_08_stop_sensor', 'Sensor de Parada', null),
      ('fbe_09_caustic_tank_lvl', 'Nível Tanque Caústico', '%'),
      ('fbe_09_acid_tank_lvl', 'Nível Tanque Ácido', '%'),
      ('fbe_09_return_conduct', 'Condutividade Retorno', 'µS/cm'),
      ('fbe_09_cip_pump_state', 'Estado Bomba CIP', null),
      ('fbe_09_flow_velocity', 'Velocidade do Fluxo CIP', 'm/s'),
      ('fbe_10_robot_1_battery', 'Bateria Robô 1', '%'),
      ('fbe_10_robot_1_location', 'Localização Robô 1', null),
      ('fbe_10_robot_1_status', 'Status Robô 1', null),
      ('fbe_10_collision_alert', 'Alerta de Colisão', null),
      ('fbe_10_payload_weight', 'Peso da Carga', 'kg'),
      ('fbe_11_grid_power_cost', 'Custo Energia Rede', 'u.m.'),
      ('fbe_11_v2g_battery_lvl', 'Nível Bateria V2G', '%'),
      ('fbe_11_main_load_draw', 'Consumo Carga Principal', 'kW'),
      ('fbe_11_grid_fault_detec', 'Detecção Falha Rede', null);
    """

    # View dimensão calendário: buckets distintos da CAGG 1min + atributos temporais (Time Intelligence no Power BI)
    execute """
    CREATE VIEW dim_calendario AS
    SELECT DISTINCT
      bucket AS ts_bucket,
      date_trunc('day', bucket)::timestamptz AS dt,
      EXTRACT(YEAR FROM bucket)::int AS year,
      EXTRACT(MONTH FROM bucket)::int AS month,
      EXTRACT(DAY FROM bucket)::int AS day,
      EXTRACT(HOUR FROM bucket)::int AS hour,
      EXTRACT(DOW FROM bucket)::int AS day_of_week
    FROM telemetry_events_1min;
    """

    # Views de fato: ts_bucket, fbe_id (para join com dim_equipamento_fbe), fact_name, avg/min/max
    execute """
    CREATE VIEW fact_telemetria_agregada_1min AS
    SELECT bucket AS ts_bucket,
      UPPER(SUBSTRING(fact_name FROM 1 FOR 7)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1min;
    """

    execute """
    CREATE VIEW fact_telemetria_agregada_1h AS
    SELECT bucket AS ts_bucket,
      UPPER(SUBSTRING(fact_name FROM 1 FOR 7)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1h;
    """

    execute """
    CREATE VIEW fact_telemetria_agregada_1day AS
    SELECT bucket AS ts_bucket,
      UPPER(SUBSTRING(fact_name FROM 1 FOR 7)) AS fbe_id,
      fact_name,
      value_float_avg AS avg_value,
      value_float_min AS min_value,
      value_float_max AS max_value
    FROM telemetry_events_1day;
    """
  end

  def down do
    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1day;"
    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1h;"
    execute "DROP VIEW IF EXISTS fact_telemetria_agregada_1min;"
    execute "DROP VIEW IF EXISTS dim_calendario;"
    drop table(:dim_variaveis_mapeamento)
    drop table(:dim_equipamento_fbe)
  end
end
