defmodule SimulacoesVisuaisWeb.SmartBreweryLive do
  @moduledoc """
  LiveView que exibe (e atualiza em tempo real) os fatos do Gêmeo Digital da Smart Brewery
  modelados com PON no `tec0301_pon`.

  Otimização de visibilidade:
  - Apenas o painel ativo (`@view_mode`: tabela, diagramas, 3d, bi) é renderizado; os outros
    não entram no DOM, evitando enviar e aplicar diffs em elementos invisíveis.
  - Seções com classe `scada-section-offscreen` usam `content-visibility: auto` para o
    navegador poder pular layout/paint quando fora da viewport.
  """

  use SimulacoesVisuaisWeb, :live_view

  alias Tec0301Pon.Examples.SmartBrewery
  alias Tec0301Pon.PON.Fato
  alias SimulacoesVisuais.SmartBrewery.FatoDescriptions
  alias SimulacoesVisuais.SmartBreweryBI
  alias SimulacoesVisuais.TelemetryEvent

  require Logger

  @max_log_entries 10
  # Evita inundar o log com a mesma regra; só registra de novo após este intervalo (ms).
  @regra_log_cooldown_ms 2_000
  # Duração do brilho visual após regra disparada.
  @regra_flash_ms 1_200
  # Throttle: acumula {:batch} do LiveViewEventBatcher e aplica em um único flush a cada N ms.
  # Config: :smart_brewery_live_flush_pending_ms em config.exs

  @fbe_descricoes %{
    1 => "Moinho_Malte",
    2 => "Tanque_Mostura",
    3 => "Tina_Filtro",
    4 => "Caldeira_Fervura",
    5 => "Trocador_Calor",
    6 => "Fermentador_A",
    7 => "Fermentador_B",
    8 => "Linha_Envase",
    9 => "Sistema_CIP",
    10 => "Frota_AMR",
    11 => "Smart_Grid"
  }

  # Descrições longas: o que é, para que serve, como age no PON (atributos notificam, métodos instigados por regras).
  @fbe_descricoes_longas %{
    1 =>
      "Elemento de Base de Fatos (FBE) que representa o moinho de malte. Encapsula estado (RPM, vibração, nível do funil, temperatura do motor) e métodos que podem ser instigados por regras (ex.: reduzir RPM, fechar válvula de alimentação). No PON, quando um atributo muda, ele notifica apenas as regras que o observam.",
    2 =>
      "FBE do tanque de mostura, onde o malte é hidratado e convertido enzimaticamente. Seus atributos (temperatura, pH, nível, vazão, status do agitador) são fontes de fatos que notificam as regras. Métodos como ligar o agitador ou ajustar a vazão de água são acionados quando regras como R_05 avaliam as condições como verdadeiras.",
    3 =>
      "FBE da tina de filtração (lautering). Representa pressão diferencial, turbidez do mosto, temperatura da água de lavagem, posição das facas e velocidade da bomba. Regras observam esses atributos e, ao disparar, instigam métodos no próprio FBE_03 (reduzir bomba, baixar facas) para evitar cavitação e otimizar a filtração.",
    4 =>
      "FBE da caldeira de fervura. Agrega temperatura de ebulição, pressão de vapor, taxa de evaporação, nível de espuma e estado do dosador de lúpulo. No PON, mudanças nesses atributos notificam premissas das regras; quando condições de segurança (NR-13) são atingidas, a regra dispara e instiga métodos como pausar dosador e reduzir pressão.",
    5 =>
      "FBE do trocador de calor, que resfria o mosto antes da fermentação. Atributos (temperaturas de entrada/saída, posição da válvula de glicol, pressão) notificam regras que otimizam o LMTD ou garantem intertravamentos. Métodos como aumentar a válvula de glicol são instigados pontualmente quando as condições são satisfeitas.",
    6 =>
      "FBE do fermentador A (cônico). Representa temperatura interna, pressão, grau Brix, estado da jaqueta de glicol, vazão de CO₂ e fase da fermentação. Regras de Smart Grid e load balancing observam esses fatos; quando disparam, podem instigar métodos como pausar o resfriamento por glicol.",
    7 =>
      "FBE do fermentador B (brite tank), espelhando os mesmos tipos de atributos do FBE_06. Participa de regras de balanceamento de carga (R_08) que cruzam temperatura, tarifa de energia e nível V2G, instigando pausa de resfriamento e descarga do buffer Vehicle-to-Grid.",
    8 =>
      "FBE da linha de envase: detecção de garrafas, velocidade da esteira, status do bico de enchimento, nível de líquido, sensores de encravamento e parada. Regras de intertravamento (R_02) observam capper_jam, liquid_lvl_detect e collision_alert; ao disparar, instigam parada de emergência da esteira e recálculo de rota dos AMRs.",
    9 =>
      "FBE do sistema CIP (Clean-In-Place): níveis dos tanques de cáustico e ácido, condutividade de retorno, estado da bomba e velocidade de fluxo. Atributos notificam regras que integram CIP com Smart Grid (R_03), podendo instigar pausa de resfriamento e descarga V2G em horário de pico.",
    10 =>
      "FBE da frota de robôs móveis autônomos (AMR). Atributos incluem bateria, localização, status e alerta de colisão. Regras observam esses fatos e, quando a bateria está baixa com robô em missão (R_11) ou há colisão na linha de envase (R_02), instigam retorno ao carregador ou recálculo de rota.",
    11 =>
      "FBE do Smart Grid: custo da tarifa, nível da bateria V2G, demanda principal e detecção de falha na rede. É observado e acionado por várias regras (R_03, R_08, R_12). Quando atributos notificam mudança (ex.: grid_fault_detec = true), a regra dispara e instiga modo ilha, load shedding e descarga V2G."
  }

  # Regra -> FBEs observados (watch) e acionados (ação). Baseado em smart_brewery_regras.ex (Artigo 05 e 11).
  @regras_fbe_map %{
    1 => %{watch: [3], action: [3]},
    2 => %{watch: [8, 10], action: [8, 10]},
    3 => %{watch: [6, 9, 11], action: [6, 11]},
    4 => %{watch: [1], action: [1]},
    5 => %{watch: [2], action: [2]},
    6 => %{watch: [4], action: [4]},
    7 => %{watch: [5], action: [5]},
    8 => %{watch: [7, 11], action: [7, 11]},
    9 => %{watch: [2, 3], action: [3]},
    10 => %{watch: [4, 5], action: [5]},
    11 => %{watch: [10], action: [10]},
    12 => %{watch: [11], action: [11]}
  }

  # FBE id -> URL do documento de exemplo 3D detalhado (priv/static/*_3d.html).
  # Cada objeto do universo 3D tem sua versão detalhada nestes documentos.
  @fbe_static_3d_url %{
    1 => "/moinho_malte_3d.html",
    2 => "/tanque_mostura_3d.html",
    3 => "/tina_filtro_3d.html",
    4 => "/caldeira_fervura_3d.html",
    5 => "/trocador_calor_3d.html",
    6 => "/fermentador_conico_3d.html",
    7 => "/fermentador_brite_3d.html",
    8 => "/linha_envase_3d.html",
    9 => "/sistema_cip_3d.html",
    10 => "/frota_amr_3d.html",
    11 => "/smart_grid_3d.html"
  }

  @view_modes [
    {"tabela", "Tabela", "Lista tabular de fatos e valores em tempo real."},
    {"diagramas", "Diagramas", "Diagramas Mermaid do pipeline e das regras."},
    {"3d", "Vista 3D", "Cena 3D do gêmeo digital; clique num equipamento para detalhes."},
    {"bi", "BI (painel analítico)",
     "Business Intelligence: gráficos e consultas analíticas sobre dados armazenados na aplicação."}
  ]

  @regras_list [
    {1, "Otimização Filtração", "diff_pressure, wort_clarity, pump_speed → FBE_03"},
    {2, "Intertravamento Envase", "capper_jam, liquid_lvl, collision → FBE_08, FBE_10"},
    {3, "Smart Grid", "internal_temp, cip_pump, grid_power → FBE_06, FBE_11"},
    {4, "Proteção Moinho", "vibração, motor_temp, hopper → FBE_01 (ISO 10816-3)"},
    {5, "Controle Mostura", "mash_temp, pH, liquid_level, agitator → FBE_02"},
    {6, "Segurança Caldeira", "foam, steam_pressure, boil_temp → FBE_04 (NR-13)"},
    {7, "Otimização Trocador", "wort_in/out_temp, glycol_valve → FBE_05 (LMTD)"},
    {8, "Load Balancing Ferm. B", "internal_temp, grid_power_cost, v2g → FBE_07, FBE_11"},
    {9, "Intertrav. Mostura→Filtro", "mash_temp, liquid_level, pump_speed → FBE_03 (ISA-88)"},
    {10, "Intertrav. Fervura→Trocador", "boil_temp, glycol_valve_pos → FBE_05"},
    {11, "Gestão Bateria AMR", "robot_battery, robot_status → FBE_10"},
    {12, "Resiliência Rede", "grid_fault_detec → FBE_11 (modo ilha, load shedding)"}
  ]

  # Descrições longas: o que a regra faz, quais fatos observa, quando dispara, que ações executa, como é acionada.
  @regras_descricoes_longas %{
    1 =>
      "Otimiza a filtração e previne cavitação. Observa os atributos diff_pressure, wort_clarity e pump_speed do FBE_03. Dispara quando os três estão simultaneamente fora da faixa (pressão > 150 mbar, turbidez < 20 NTU, bomba > 50%). A ação instiga no FBE_03: reduzir bomba em 10% e baixar as facas. A regra só é avaliada quando algum desses atributos notifica uma mudança; então as premissas e a condição AND são reavaliadas e, se verdadeiras, a ação executa.",
    2 =>
      "Intertravamento crítico da linha de envase. Observa capper_jam_sens (FBE_08), liquid_lvl_detect (FBE_08) e collision_alert (FBE_10). Dispara se qualquer um indicar falha: encravamento na arrolhadora, nível de líquido com falha ou alerta de colisão do AMR. Ação: parada de emergência da esteira (FBE_08) e recálculo de rota de evitação (FBE_10). É acionada pontualmente quando um desses fatos notifica mudança e a condição OR fica verdadeira.",
    3 =>
      "Gestão de demanda energética (Smart Grid). Observa temperatura interna do fermentador A (FBE_06), estado da bomba CIP (FBE_09) e custo da tarifa (FBE_11). Dispara quando fermentação está estável (< 19°C), CIP ligado e tarifa em pico (> 150). Ação: pausar resfriamento por glicol no FBE_06 e descarregar buffer V2G no FBE_11. A regra é acionada apenas quando algum dos três atributos notifica; a condição AND é então reavaliada.",
    4 =>
      "Proteção do moinho (ISO 10816-3). Observa temperatura do motor, vibração, nível do funil, RPM e estado da válvula de alimentação (FBE_01). Dispara se vibração > 80, ou motor > 70°C, ou funil baixo com motor ligado. Ação: reduzir RPM; se vibração > 95, fechar válvula de alimentação. A regra só reage quando um desses fatos notifica; evita desgaste e cavitação.",
    5 =>
      "Controle da mostura. Observa temperatura do mosto, pH, nível de líquido e status do agitador (FBE_02). Dispara se temperatura fora da faixa enzimática (60–72°C), ou pH fora de 5,0–5,8, ou nível alto com agitador desligado. Ação: ligar agitador e ajustar vazão de água. Acionada quando qualquer um desses atributos notifica e a condição fica verdadeira.",
    6 =>
      "Segurança da caldeira (NR-13). Observa espuma, pressão de vapor, temperatura de ebulição e estado do dosador de lúpulo (FBE_04). Dispara se espuma alta, pressão > 4 bar ou fervura > 103°C com dosador ativo. Ação: pausar dosador de lúpulo e reduzir pressão de vapor. A regra é avaliada somente quando um desses atributos notifica mudança.",
    7 =>
      "Otimização do trocador de calor (LMTD). Observa temperaturas de entrada e saída do mosto e posição da válvula de glicol (FBE_05). Dispara quando mosto quente na entrada (> 80°C), saída ainda quente (> 20°C) e válvula com margem (< 90%). Ação: aumentar abertura da válvula de glicol. Acionada pontualmente quando um dos fatos observados notifica.",
    8 =>
      "Load balancing do fermentador B. Observa temperatura interna (FBE_07), custo da tarifa e nível V2G (FBE_11). Dispara quando fermentação estável (< 19°C), tarifa em pico e bateria V2G disponível (> 20%). Ação: pausar resfriamento no FBE_07 e descarregar buffer V2G no FBE_11. A regra é acionada quando algum desses atributos notifica e a condição AND é satisfeita.",
    9 =>
      "Intertravamento Mostura → Filtro (ISA-88). Observa temperatura e nível do mostura (FBE_02) e velocidade da bomba (FBE_03). Dispara se a bomba estiver ligada com mostura não pronta (temperatura < 65°C ou nível < 50%). Ação: zerar a bomba no FBE_03. Garante que o mosto só seja transferido quando a mostura estiver no ponto; acionada quando um dos fatos notifica.",
    10 =>
      "Intertravamento Fervura → Trocador. Observa temperatura da caldeira (FBE_04) e posição da válvula de glicol (FBE_05). Dispara quando fervura ativa (> 95°C) e válvula de glicol fechada (0). Ação: aumentar abertura da válvula no FBE_05 para evitar receber mosto quente sem capacidade de resfriamento. Acionada quando um dos dois atributos notifica.",
    11 =>
      "Gestão da bateria dos AMRs. Observa nível de bateria e status do robô (FBE_10). Dispara quando bateria < 20% e robô não está ocioso (em missão ou carregando). Ação: solicitar retorno à estação de carregamento. A regra é acionada quando bateria ou status notificam mudança, evitando que o robô pare longe do carregador.",
    12 =>
      "Resiliência da rede. Observa apenas grid_fault_detec (FBE_11). Dispara quando há falha detectada na rede (true). Ação: ativar modo ilha, fazer load shedding de cargas não críticas e descarregar buffer V2G. A regra é acionada exclusivamente quando o atributo de falha notifica a mudança, permitindo resposta imediata à queda de energia."
  }

  @impl true
  def mount(_params, _session, socket) do
    _ = SimulacoesVisuais.SmartBrewery.CaseContext.new_session()

    # Lista fixa dos 57 fatos expostos pelo SmartBrewery.
    fatos_names = SmartBrewery.fatos_names()

    # Consegue ler valores iniciais quando os processos Fato já estiverem vivos.
    fatos =
      Enum.into(fatos_names, %{}, fn nome ->
        {nome, safe_obter_fato(nome)}
      end)

    # LiveView recebe lotes de fatos do LiveViewEventBatcher (janela de eventos); OEE, anomalias e regras em tópicos separados.
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, "smart_brewery:liveview_batch")
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, "smart_brewery:oee")
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, "smart_brewery:anomalias")
    Phoenix.PubSub.subscribe(SimulacoesVisuais.PubSub, "smart_brewery:regras")

    # Agrupamento por FBE_01..FBE_11 (para UI mais legível).
    fatos_por_fbe =
      Enum.map(1..11, fn fbe_id ->
        {fbe_id, Enum.filter(fatos_names, fn nome -> fbe_id(nome) == fbe_id end)}
      end)

    initial_entry = log_entry("sistema", "LiveView conectada. Aguardando notificações PON.")

    bi_filters = SmartBreweryBI.default_filters()
    bi_options = SmartBreweryBI.options()
    bi_data = SmartBreweryBI.dashboard_data(bi_filters)

    socket =
      assign(socket,
        fatos_names: fatos_names,
        fatos: fatos,
        fatos_prev: fatos,
        fatos_por_fbe: fatos_por_fbe,
        fbe_static_3d_url: @fbe_static_3d_url,
        fbe_descricoes_longas: @fbe_descricoes_longas,
        view_modes: @view_modes,
        regras_list: @regras_list,
        regras_descricoes_longas: @regras_descricoes_longas,
        regra_expandida: nil,
        simulando: false,
        monte_carlo_ativo: monte_carlo_ui_active?(socket),
        view_mode: "tabela",
        open_fbes: MapSet.new(),
        scene_3d_selected_fbe: nil,
        scene_3d_hovered_fbe: nil,
        event_log_count: 1,
        max_log_entries: @max_log_entries,
        oee_percent: SimulacoesVisuais.SmartBrewery.OEE.get(),
        oee_components: SimulacoesVisuais.SmartBrewery.OEE.get_components(),
        ema_control_limits: safe_ema_control_limits(),
        anomalia_fbes: MapSet.new(),
        pending_anomalia_fbes: MapSet.new(),
        sparkline_data: sparkline_init_from_fatos(fatos),
        tsdb_enabled: Application.get_env(:simulacoes_visuais, :tsdb_enabled, false),
        tsdb_connected:
          (Application.get_env(:simulacoes_visuais, :tsdb_enabled, false) &&
             check_tsdb_connection()) ||
            nil,
        last_regra_log_at: %{},
        regra_flash_fbes: MapSet.new(),
        regra_flash_timers: %{},
        pending_fato_updates: %{},
        flush_timer_ref: nil,
        bi_filters: bi_filters,
        bi_options: bi_options,
        bi_data: bi_data,
        bi_form: to_form(bi_filters, as: :bi_filters),
        bi_refresh_timer_ref: nil
      )
      |> stream(:event_log, [initial_entry], dom_id: fn e -> "log-#{e.id}" end)
      |> then(fn s ->
        cond do
          s.assigns.tsdb_enabled ->
            Process.send_after(self(), :fetch_tsdb_sparklines, 3000)
            Process.send_after(self(), :check_tsdb_connection, 30_000)
            s

          true ->
            s
        end
      end)

    {:ok, socket}
  end

  @impl true
  def handle_info({:batch, updates}, socket) when is_list(updates) do
    pending = Enum.into(updates, %{}, fn {k, v} -> {k, v} end)
    socket = add_pending_and_schedule_flush(socket, pending)
    {:noreply, socket}
  end

  def handle_info(:flush_pending_fatos, socket) do
    pending = socket.assigns.pending_fato_updates

    socket =
      socket
      |> assign(:flush_timer_ref, nil)
      |> assign(:pending_fato_updates, %{})

    if pending == %{} do
      {:noreply, socket}
    else
      list = Map.to_list(pending)

      new_fatos =
        Enum.reduce(list, socket.assigns.fatos, fn {nome, valor}, acc ->
          Map.put(acc, nome, valor)
        end)

      new_spark =
        if socket.assigns.tsdb_enabled,
          do: socket.assigns.sparkline_data,
          else: sparkline_update(socket.assigns.sparkline_data, list)

      entry = log_entry("fato", "#{map_size(pending)} atualizações aplicadas")

      merged_anomalia_fbes =
        MapSet.union(socket.assigns.anomalia_fbes, socket.assigns.pending_anomalia_fbes)

      socket =
        socket
        |> assign(:fatos_prev, socket.assigns.fatos)
        |> assign(:fatos, new_fatos)
        |> assign(:sparkline_data, new_spark)
        |> assign(:anomalia_fbes, merged_anomalia_fbes)
        |> assign(:pending_anomalia_fbes, MapSet.new())
        |> append_event_log(entry)

      {:noreply, socket}
    end
  end

  def handle_info({:simulacao_concluida}, socket) do
    entry = log_entry("sistema", "Simulação concluída.")

    socket
    |> append_event_log(entry)
    |> assign(simulando: false)
    |> then(fn s -> {:noreply, s} end)
  end

  def handle_info({:oee_update, pct, components}, socket) when is_map(components) do
    socket =
      socket
      |> assign(:oee_percent, pct)
      |> assign(:oee_components, components)

    {:noreply, socket}
  end

  def handle_info({:anomalia, nome_fato, _valor, _ema, _sigma}, socket) do
    fbe_id = fbe_id(nome_fato)

    new_pending =
      if fbe_id,
        do: MapSet.put(socket.assigns.pending_anomalia_fbes, fbe_id),
        else: socket.assigns.pending_anomalia_fbes

    {:noreply, assign(socket, :pending_anomalia_fbes, new_pending)}
  end

  # Artigo 07 §6.1/§7: sparklines a partir do TSDB quando tsdb_enabled (últimos 60 min).
  # Debounce: só registra a mesma regra no log após @regra_log_cooldown_ms para não inundar com disparos repetidos.
  def handle_info({:regra, regra_id}, socket) do
    now = DateTime.utc_now()
    last = Map.get(socket.assigns.last_regra_log_at, regra_id)
    skip? = last && DateTime.diff(now, last, :millisecond) < @regra_log_cooldown_ms

    action_fbes =
      @regras_fbe_map
      |> Map.get(regra_id, %{})
      |> Map.get(:action, [])

    socket = flash_fbes_from_rule(socket, action_fbes)

    socket =
      if skip? do
        socket
      else
        entry = log_entry("regra", "Regra disparada: #{regra_id}")

        socket
        |> append_event_log(entry)
        |> assign(:last_regra_log_at, Map.put(socket.assigns.last_regra_log_at, regra_id, now))
      end

    {:noreply, socket}
  end

  def handle_info({:clear_regra_flash_fbe, fbe_id}, socket) when is_integer(fbe_id) do
    new_flash = MapSet.delete(socket.assigns.regra_flash_fbes, fbe_id)
    new_timers = Map.delete(socket.assigns.regra_flash_timers, fbe_id)

    {:noreply, assign(socket, regra_flash_fbes: new_flash, regra_flash_timers: new_timers)}
  end

  def handle_info(:check_tsdb_connection, socket) do
    connected =
      if socket.assigns.tsdb_enabled do
        check_tsdb_connection()
      else
        nil
      end

    socket =
      socket
      |> assign(:tsdb_connected, connected)
      |> then(fn s ->
        if s.assigns.tsdb_enabled, do: Process.send_after(self(), :check_tsdb_connection, 30_000)
        s
      end)

    {:noreply, socket}
  end

  def handle_info(:fetch_tsdb_sparklines, socket) do
    socket =
      if socket.assigns.tsdb_enabled do
        new_spark =
          Enum.reduce(1..11, socket.assigns.sparkline_data, fn fbe_id, acc ->
            key = fbe_tile_key_fact(fbe_id)

            if key do
              try do
                series =
                  TelemetryEvent.list_series(Atom.to_string(key), 60, 500)

                # Ordem já é oldest-first (ORDER BY ts ASC). Filtrar nils do value_float.
                values =
                  Enum.map(series, fn %{value: v} -> v end)
                  |> Enum.reject(&is_nil/1)
                  |> Enum.take(60)

                if values != [], do: Map.put(acc, fbe_id, values), else: acc
              rescue
                _ -> acc
              end
            else
              acc
            end
          end)

        Process.send_after(self(), :fetch_tsdb_sparklines, 10_000)
        assign(socket, :sparkline_data, new_spark)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:refresh_bi_dashboard, socket) do
    socket = cancel_bi_dashboard_refresh(socket)

    if socket.assigns.view_mode == "bi" and socket.assigns.tsdb_enabled and
         bi_dashboard_refresh_ms() > 0 do
      filters = socket.assigns.bi_filters
      data = SmartBreweryBI.dashboard_data(filters)

      {:noreply,
       socket
       |> assign(:bi_data, data)
       |> schedule_bi_dashboard_refresh()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_view", %{"mode" => mode}, socket)
      when mode in ["tabela", "diagramas", "3d", "bi"] do
    prev_mode = socket.assigns.view_mode

    socket =
      socket
      |> then(fn s -> if mode == "3d", do: s, else: assign(s, scene_3d_selected_fbe: nil) end)

    socket =
      if prev_mode == "bi" and mode != "bi" do
        cancel_bi_dashboard_refresh(socket)
      else
        socket
      end

    socket =
      if mode == "bi" do
        filters = socket.assigns.bi_filters

        socket
        |> assign(:bi_options, SmartBreweryBI.options())
        |> assign(:bi_data, SmartBreweryBI.dashboard_data(filters))
        |> assign(:bi_form, to_form(filters, as: :bi_filters))
        |> schedule_bi_dashboard_refresh()
      else
        socket
      end

    {:noreply, assign(socket, view_mode: mode)}
  end

  @impl true
  def handle_event("bi_filters_change", %{"bi_filters" => params}, socket) do
    filters = SmartBreweryBI.normalize_filters(params)
    data = SmartBreweryBI.dashboard_data(filters)

    socket =
      socket
      |> assign(:bi_filters, filters)
      |> assign(:bi_data, data)
      |> assign(:bi_form, to_form(filters, as: :bi_filters))
      |> cancel_bi_dashboard_refresh()
      |> schedule_bi_dashboard_refresh()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_fbe_3d", %{"id" => id}, socket) do
    selected = parse_fbe_2d_id(id)
    {:noreply, assign(socket, scene_3d_selected_fbe: selected)}
  end

  @impl true
  def handle_event("hover_fbe_3d", %{"id" => id}, socket) do
    hovered = parse_fbe_2d_id(id)
    {:noreply, assign(socket, scene_3d_hovered_fbe: hovered)}
  end

  @impl true
  def handle_event("toggle_fbe", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    open = socket.assigns.open_fbes

    new_open =
      if MapSet.member?(open, id),
        do: MapSet.delete(open, id),
        else: MapSet.put(open, id)

    {:noreply, assign(socket, open_fbes: new_open)}
  end

  def handle_event("toggle_regra", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    new_expandida = if socket.assigns.regra_expandida == id, do: nil, else: id
    {:noreply, assign(socket, regra_expandida: new_expandida)}
  end

  @impl true
  def handle_event("start_monte_carlo", _params, %{assigns: %{monte_carlo_ativo: true}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_monte_carlo", _params, socket) do
    SimulacoesVisuais.SmartBreweryMonteCarlo.start_loop()

    entry =
      log_entry(
        "sistema",
        "Monte Carlo iniciado. Atualizações aleatórias periódicas (intervalo configurável em config)."
      )

    socket =
      socket
      |> append_event_log(entry)
      |> assign(monte_carlo_ativo: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_monte_carlo", _params, socket) do
    SimulacoesVisuais.SmartBreweryMonteCarlo.stop_loop()
    entry = log_entry("sistema", "Monte Carlo parado.")

    socket =
      socket
      |> append_event_log(entry)
      |> assign(monte_carlo_ativo: false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("run_simulacao", _params, %{assigns: %{simulando: true}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("run_simulacao", _params, socket) do
    lv_pid = self()
    entry = log_entry("sistema", "Simulação iniciada (R_01, R_02, R_03).")
    socket = append_event_log(socket, entry)

    Task.start(fn ->
      SmartBrewery.simular()
      send(lv_pid, {:simulacao_concluida})
    end)

    {:noreply, assign(socket, simulando: true)}
  end

  defp log_entry(type, msg) do
    at = DateTime.utc_now() |> DateTime.to_string()
    %{id: System.unique_integer([:positive]), at: at, type: type, msg: msg}
  end

  defp monte_carlo_ui_active?(socket) do
    connected?(socket) && SimulacoesVisuais.SmartBreweryMonteCarlo.running?()
  end

  defp check_tsdb_connection do
    case SimulacoesVisuais.Repo.query("SELECT 1") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  rescue
    _ -> false
  end

  defp sparkline_update(data, updates) do
    Enum.reduce(updates, data, fn {nome, valor}, acc ->
      if is_number(valor) do
        fbe_id = fbe_id(nome)

        if fbe_id do
          # Sempre oldest-first (igual ao TSDB): append no final e manter últimos 60.
          list = (Map.get(acc, fbe_id, []) ++ [valor]) |> take_last(60)
          Map.put(acc, fbe_id, list)
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp take_last(list, n) when length(list) <= n, do: list
  defp take_last(list, n), do: list |> Enum.drop(length(list) - n)

  defp sparkline_points(list, width, height) when list != [] do
    # Dados são sempre oldest-first (TSDB e sparkline_update). Esquerda = antigo, direita = novo.
    pts = list
    # Com um único ponto desenhamos um segmento horizontal para ficar visível.
    pts = if length(pts) == 1, do: List.duplicate(hd(pts), 2), else: pts
    mn = Enum.min(pts)
    mx = Enum.max(pts)
    range = max(mx - mn, 1)
    n = length(pts)
    step = if n <= 1, do: width, else: width / (n - 1)

    pts
    |> Enum.with_index()
    |> Enum.map(fn {v, i} ->
      x = i * step
      # SVG: y=0 no topo; valor maior = mais alto na tela.
      y = height - (v - mn) / range * height
      "#{Float.round(x, 2)},#{Float.round(y, 2)}"
    end)
    |> Enum.join(" ")
  end

  defp sparkline_points([], _w, _h), do: ""

  # Inicializa sparkline_data com os valores atuais dos fatos para os gráficos aparecerem logo.
  # Aceita número ou string numérica.
  defp sparkline_init_from_fatos(fatos) do
    Enum.reduce(1..11, %{}, fn fbe_id, acc ->
      key = fbe_tile_key_fact(fbe_id)
      raw = key && Map.get(fatos, key)
      num = to_sparkline_number(raw)

      if key && num != nil do
        Map.put(acc, fbe_id, [num])
      else
        acc
      end
    end)
  end

  defp to_sparkline_number(n) when is_integer(n), do: n * 1.0
  defp to_sparkline_number(n) when is_float(n), do: n

  defp to_sparkline_number(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp to_sparkline_number(_), do: nil

  defp append_event_log(socket, entry) do
    new_count = min(@max_log_entries, socket.assigns.event_log_count + 1)

    socket
    |> assign(:event_log_count, new_count)
    |> stream_insert(:event_log, entry, at: 0, limit: -@max_log_entries)
  end

  defp flush_pending_ms do
    Application.get_env(:simulacoes_visuais, :smart_brewery_live_flush_pending_ms, 280)
  end

  defp bi_dashboard_refresh_ms do
    case Application.get_env(:simulacoes_visuais, :bi_dashboard_refresh_ms, 10_000) do
      n when is_integer(n) and n > 0 -> n
      _ -> 0
    end
  end

  defp cancel_bi_dashboard_refresh(socket) do
    case socket.assigns.bi_refresh_timer_ref do
      ref when is_reference(ref) -> Process.cancel_timer(ref)
      _ -> :ok
    end

    assign(socket, :bi_refresh_timer_ref, nil)
  end

  defp schedule_bi_dashboard_refresh(socket) do
    ms = bi_dashboard_refresh_ms()

    if ms > 0 && socket.assigns.tsdb_enabled do
      ref = Process.send_after(self(), :refresh_bi_dashboard, ms)
      assign(socket, :bi_refresh_timer_ref, ref)
    else
      assign(socket, :bi_refresh_timer_ref, nil)
    end
  end

  defp add_pending_and_schedule_flush(socket, new_updates) when new_updates != %{} do
    pending = Map.merge(socket.assigns.pending_fato_updates, new_updates)
    socket = assign(socket, :pending_fato_updates, pending)

    if socket.assigns.flush_timer_ref do
      socket
    else
      ref = Process.send_after(self(), :flush_pending_fatos, flush_pending_ms())
      assign(socket, :flush_timer_ref, ref)
    end
  end

  defp add_pending_and_schedule_flush(socket, _), do: socket

  defp safe_ema_control_limits do
    try do
      SimulacoesVisuais.SmartBrewery.EMA.get_control_limits()
    rescue
      _e -> %{}
    end
  end

  defp safe_obter_fato(nome_do_fato) do
    try do
      Fato.obter(nome_do_fato)
    rescue
      _e ->
        Logger.debug("[SmartBreweryLive] Não foi possível ler #{nome_do_fato}.")
        nil
    end
  end

  defp fbe_id(nome_atom) do
    nome = Atom.to_string(nome_atom)

    case String.split(nome, "_", parts: 3) do
      ["fbe", id_str, _rest] -> String.to_integer(id_str)
      _ -> nil
    end
  end

  defp pad2(n) do
    n |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  defp attr_label(nome_atom) do
    nome = Atom.to_string(nome_atom)

    case String.split(nome, "_", parts: 3) do
      ["fbe", _id_str, rest] -> rest
      _ -> nome
    end
  end

  defp format_value(nil), do: "-"
  defp format_value(v) when is_binary(v), do: v
  defp format_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_value(v), do: inspect(v)

  # Facts for the iframe "Modelo 3D detalhado" (postMessage payload).
  defp fbe_facts_for_iframe(assigns) do
    fbe_id = assigns[:scene_3d_selected_fbe]

    if is_nil(fbe_id) or is_nil(Map.get(assigns.fbe_static_3d_url, fbe_id)) do
      []
    else
      fatos_por_fbe = Map.new(assigns.fatos_por_fbe)
      nomes = fatos_por_fbe[fbe_id] || []

      Enum.map(nomes, fn nome ->
        %{
          label: attr_label(nome),
          description: FatoDescriptions.descricao(nome),
          value: format_value(assigns.fatos[nome])
        }
      end)
    end
  end

  defp fbe_detail_rows(assigns, fbe_id) do
    fatos_por_fbe = Map.new(assigns.fatos_por_fbe)
    nomes = fatos_por_fbe[fbe_id] || []

    Enum.map(nomes, fn nome ->
      {attr_label(nome), FatoDescriptions.descricao(nome), format_value(assigns.fatos[nome])}
    end)
  end

  defp format_scada_number(nil), do: "-"
  defp format_scada_number(v) when is_integer(v), do: to_string(v)
  defp format_scada_number(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 2)
  defp format_scada_number(_), do: "-"

  defp delta_display(fatos, fatos_prev, nome, _) do
    cur = Map.get(fatos, nome)
    prev = Map.get(fatos_prev, nome)

    if is_number(cur) and is_number(prev) and prev != 0 do
      diff = cur - prev
      pct = 100.0 * diff / prev

      if diff > 0,
        do: "+#{:erlang.float_to_binary(pct, decimals: 1)}%",
        else: "#{:erlang.float_to_binary(pct, decimals: 1)}%"
    else
      nil
    end
  end

  defp fbe_tile_key_fact(1), do: :fbe_01_motor_temp
  defp fbe_tile_key_fact(2), do: :fbe_02_mash_temp
  defp fbe_tile_key_fact(3), do: :fbe_03_diff_pressure
  defp fbe_tile_key_fact(4), do: :fbe_04_boil_temp
  defp fbe_tile_key_fact(5), do: :fbe_05_wort_out_temp
  defp fbe_tile_key_fact(6), do: :fbe_06_internal_temp
  defp fbe_tile_key_fact(7), do: :fbe_07_internal_temp
  defp fbe_tile_key_fact(8), do: :fbe_08_conveyor_speed
  defp fbe_tile_key_fact(9), do: :fbe_09_flow_velocity
  defp fbe_tile_key_fact(10), do: :fbe_10_robot_1_battery
  defp fbe_tile_key_fact(11), do: :fbe_11_grid_power_cost
  defp fbe_tile_key_fact(_), do: nil

  defp flash_fbes_from_rule(socket, []), do: socket

  defp flash_fbes_from_rule(socket, fbe_ids) when is_list(fbe_ids) do
    Enum.reduce(fbe_ids, socket, fn fbe_id, acc ->
      old_ref = Map.get(acc.assigns.regra_flash_timers, fbe_id)
      if old_ref, do: Process.cancel_timer(old_ref)

      timer_ref = Process.send_after(self(), {:clear_regra_flash_fbe, fbe_id}, @regra_flash_ms)

      acc
      |> assign(:regra_flash_fbes, MapSet.put(acc.assigns.regra_flash_fbes, fbe_id))
      |> assign(:regra_flash_timers, Map.put(acc.assigns.regra_flash_timers, fbe_id, timer_ref))
    end)
  end

  defp fbe_descricao(fbe_id) do
    Map.get(@fbe_descricoes, fbe_id, "")
  end

  defp parse_fbe_2d_id(nil), do: nil
  defp parse_fbe_2d_id(""), do: nil

  defp parse_fbe_2d_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, _} when n in 1..11 -> n
      _ -> nil
    end
  end

  defp parse_fbe_2d_id(n) when n in 1..11, do: n
  defp parse_fbe_2d_id(_), do: nil

  defp build_scene_state(assigns) do
    fatos = assigns.fatos
    fatos_por_fbe = Map.new(assigns.fatos_por_fbe)

    for i <- 1..11 do
      label = fbe_descricao(i) |> String.replace("_", " ")
      {value, status} = scene_fbe_value_status(i, fatos)
      fact_names = fatos_por_fbe[i] || []

      facts =
        Enum.into(fact_names, %{}, fn nome ->
          {attr_label(nome), format_value(fatos[nome])}
        end)

      %{id: i, label: label, value: value, status: status, facts: facts}
    end
  end

  defp scene_fbe_value_status(1, fatos), do: {Map.get(fatos, :fbe_01_motor_rpm), :normal}
  defp scene_fbe_value_status(2, fatos), do: {Map.get(fatos, :fbe_02_mash_temp), :normal}

  defp scene_fbe_value_status(3, fatos) do
    v = Map.get(fatos, :fbe_03_diff_pressure)
    status = if is_number(v) and v > 150, do: :warning, else: :normal
    {v, status}
  end

  defp scene_fbe_value_status(4, fatos), do: {Map.get(fatos, :fbe_04_boil_temp), :normal}
  defp scene_fbe_value_status(5, fatos), do: {Map.get(fatos, :fbe_05_wort_out_temp), :normal}

  defp scene_fbe_value_status(6, fatos) do
    v = Map.get(fatos, :fbe_06_internal_temp)
    status = if is_number(v) and v < 19, do: :active, else: :normal
    {v, status}
  end

  defp scene_fbe_value_status(7, fatos), do: {Map.get(fatos, :fbe_07_internal_temp), :normal}

  defp scene_fbe_value_status(8, fatos) do
    lvl = Map.get(fatos, :fbe_08_liquid_lvl_detect)
    jam = Map.get(fatos, :fbe_08_capper_jam_sens)
    status = if lvl == :fail or jam == true, do: :warning, else: :normal
    {lvl, status}
  end

  defp scene_fbe_value_status(9, fatos) do
    v = Map.get(fatos, :fbe_09_cip_pump_state)
    status = if v == :on, do: :active, else: :normal
    {v, status}
  end

  defp scene_fbe_value_status(10, fatos) do
    v = Map.get(fatos, :fbe_10_collision_alert)
    status = if v == true, do: :warning, else: :normal
    {v, status}
  end

  defp scene_fbe_value_status(11, fatos) do
    fault = Map.get(fatos, :fbe_11_grid_fault_detec) == true
    v = Map.get(fatos, :fbe_11_grid_power_cost)

    status =
      cond do
        fault -> :critical
        is_number(v) and v > 150 -> :warning
        true -> :normal
      end

    {v, status}
  end

  defp build_mermaid_grafo_pon(assigns) do
    fatos = assigns.fatos
    # Nós: R_01..R_12, F01..F11. Labels curtos.
    rule_nodes =
      for i <- 1..12 do
        label = if i < 10, do: "R_0#{i}", else: "R_#{i}"
        "R#{i}[\"#{label}\"]"
      end

    fbe_nodes =
      for i <- 1..11 do
        label = fbe_descricao(i) |> String.replace("_", " ")
        hint = fbe_hint_value(fatos, i)
        node_label = if hint != "", do: "#{label} #{hint}", else: label
        # Escapar aspas no label para Mermaid
        safe_label = String.replace(node_label, "\"", "'")
        "F#{i}[\"#{safe_label}\"]"
      end

    edges_observa =
      for {regra_id, %{watch: watch}} <- @regras_fbe_map,
          fbe_id <- watch do
        "R#{regra_id} -->|\"observa\"| F#{fbe_id}"
      end

    edges_aciona =
      for {regra_id, %{action: action}} <- @regras_fbe_map,
          fbe_id <- action do
        "R#{regra_id} -->|\"aciona\"| F#{fbe_id}"
      end

    lines =
      ["flowchart LR"] ++ rule_nodes ++ fbe_nodes ++ edges_observa ++ edges_aciona

    Enum.join(lines, "\n")
  end

  defp fbe_hint_value(fatos, fbe_id) do
    # Um fato representativo por FBE para anotar o nó (tempo real).
    key =
      case fbe_id do
        3 -> :fbe_03_diff_pressure
        6 -> :fbe_06_internal_temp
        8 -> :fbe_08_liquid_lvl_detect
        9 -> :fbe_09_cip_pump_state
        10 -> :fbe_10_collision_alert
        11 -> :fbe_11_grid_power_cost
        _ -> nil
      end

    case key && Map.get(fatos, key) do
      nil -> ""
      v -> "(" <> format_value(v) <> ")"
    end
  end

  defp build_mermaid_pipeline(assigns) do
    fatos = assigns.fatos
    # Pipeline: FBE_01 -> FBE_02 -> ... -> FBE_11. Labels = descrição curta.
    node_ids = 1..11 |> Enum.map(&"P#{&1}")

    labels =
      for i <- 1..11 do
        desc = fbe_descricao(i) |> String.replace("_", " ")
        hint = fbe_hint_value(fatos, i)
        if hint != "", do: "#{desc} #{hint}", else: desc
      end

    nodes =
      node_ids
      |> Enum.zip(labels)
      |> Enum.map(fn {id, label} ->
        safe = String.replace(label, "\"", "'")
        "#{id}[\"#{safe}\"]"
      end)

    edges =
      Enum.zip(node_ids, tl(node_ids))
      |> Enum.map(fn {a, b} -> "#{a} --> #{b}" end)

    lines = ["flowchart TB"] ++ nodes ++ edges
    Enum.join(lines, "\n")
  end

  defp bi_d3_ts_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp bi_d3_ts_iso(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)

  defp bi_d3_ts_iso(t) when is_binary(t), do: t
  defp bi_d3_ts_iso(_), do: nil

  defp bi_d3_num(%Decimal{} = d), do: Decimal.to_float(d)
  defp bi_d3_num(v) when is_number(v), do: v * 1.0
  defp bi_d3_num(_), do: nil

  defp bi_d3_oee_payload(oee_trend) when is_list(oee_trend) do
    rows =
      oee_trend
      |> Enum.map(fn r ->
        %{
          t: bi_d3_ts_iso(Map.get(r, :ts)),
          oee: bi_d3_num(Map.get(r, :oee)),
          availability: bi_d3_num(Map.get(r, :availability)),
          performance: bi_d3_num(Map.get(r, :performance)),
          quality: bi_d3_num(Map.get(r, :quality))
        }
      end)
      |> Enum.reject(&(is_nil(&1.t) or &1.t == ""))

    %{
      kind: "multi_y",
      rows: rows,
      series: [
        %{key: "oee", color: "primary", label: "OEE"},
        %{key: "availability", color: "success", label: "A · disponibilidade"},
        %{key: "performance", color: "warning", label: "P · desempenho"},
        %{key: "quality", color: "info", label: "Q · qualidade"}
      ]
    }
  end

  defp bi_d3_telemetry_payload(telemetry_trend) when is_list(telemetry_trend) do
    rows =
      telemetry_trend
      |> Enum.map(fn r ->
        %{t: bi_d3_ts_iso(Map.get(r, :ts)), y: bi_d3_num(Map.get(r, :value))}
      end)
      |> Enum.reject(&(is_nil(&1.t) or &1.t == "" or is_nil(&1.y)))

    %{kind: "single_y", rows: rows, color: "secondary"}
  end

  defp bi_d3_ref_line(v, color, dash?) do
    case bi_d3_num(v) do
      nil ->
        nil

      vf ->
        m = %{value: vf, color: color}
        if dash?, do: Map.put(m, :dash, true), else: m
    end
  end

  defp bi_d3_cep_payload(cep) when is_map(cep) do
    points = Map.get(cep, :points, [])

    rows =
      points
      |> Enum.map(fn r ->
        %{t: bi_d3_ts_iso(Map.get(r, :ts)), y: bi_d3_num(Map.get(r, :value))}
      end)
      |> Enum.reject(&(is_nil(&1.t) or &1.t == "" or is_nil(&1.y)))

    ref_lines =
      [
        bi_d3_ref_line(Map.get(cep, :cl), "base-content", false),
        bi_d3_ref_line(Map.get(cep, :ucl), "warning", true),
        bi_d3_ref_line(Map.get(cep, :lcl), "warning", true)
      ]
      |> Enum.reject(&is_nil/1)

    %{kind: "cep", rows: rows, color: "accent", ref_lines: ref_lines}
  end

  defp bi_max_total([]), do: 1

  defp bi_max_total(items) do
    items
    |> Enum.map(&Map.get(&1, :total, 0))
    |> Enum.max(fn -> 1 end)
    |> max(1)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide={true} current_path="/smart-brewery">
      <div class="scada-panel min-h-screen bg-base-300/30">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-6 space-y-6">
          <%!-- Barra superior: título + controles (hierarquia F/Z) --%>
          <header class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="flex items-center gap-3">
              <.link
                navigate={~p"/"}
                class="btn btn-ghost btn-sm btn-square transition-colors"
                aria-label="Voltar ao início"
              >
                <.icon name="hero-arrow-left" class="size-5" />
              </.link>
              <div>
                <h1 class="text-2xl sm:text-3xl font-bold tracking-tight text-base-content flex flex-wrap items-baseline gap-x-1.5 gap-y-0">
                  <.tech_term term={:gemeo_digital} aria_describedby_glossary />
                  <span class="text-base-content/50 font-normal">·</span>
                  <span>Smart Brewery</span>
                </h1>
                <p class="text-sm text-base-content/70 mt-0.5 flex flex-wrap items-baseline gap-x-1 gap-y-0.5">
                  <.tech_term term={:pon} aria_describedby_glossary />
                  <span class="text-base-content/50">·</span>
                  <span>57</span>
                  <.tech_term
                    term={:fato_pon}
                    text="fatos"
                    aria_describedby_glossary
                    show_glossary_link
                  />
                  <span class="text-base-content/50">,</span>
                  <span>12</span>
                  <.tech_term
                    term={:regra_pon}
                    text="regras"
                    aria_describedby_glossary
                    show_glossary_link
                  />
                  <span class="text-base-content/50">·</span>
                  <span>atualizações em tempo real</span>
                </p>
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <div class="stats shadow bg-base-100">
                <div class="stat py-3 px-4 min-w-0">
                  <div class="stat-title text-xs">Estado</div>
                  <div class="stat-value text-lg">
                    <%= if @simulando do %>
                      <span class="badge badge-warning gap-1 animate-pulse">Simulando</span>
                    <% else %>
                      <%= if @monte_carlo_ativo do %>
                        <span class="badge badge-info gap-1 animate-pulse inline-flex items-center">
                          <.tech_term
                            term={:monte_carlo}
                            aria_describedby_glossary
                            class="decoration-white/50 border-white/30"
                          />
                        </span>
                      <% else %>
                        <span class="badge badge-success gap-1">Pronto</span>
                      <% end %>
                    <% end %>
                  </div>
                </div>
              </div>
              <%= if @monte_carlo_ativo do %>
                <button
                  type="button"
                  phx-click="stop_monte_carlo"
                  phx-click-loading
                  class="btn btn-outline btn-error gap-2 font-semibold transition-colors"
                >
                  <.icon name="hero-stop" class="size-5 phx-click-loading:animate-spin" /> Parar
                  <.tech_term term={:monte_carlo} aria_describedby_glossary />
                </button>
              <% else %>
                <button
                  type="button"
                  phx-click="start_monte_carlo"
                  phx-click-loading
                  disabled={@simulando}
                  class={[
                    "btn gap-2 font-semibold transition-colors",
                    @simulando && "btn-disabled",
                    !@simulando && "btn-secondary"
                  ]}
                >
                  <.icon name="hero-arrow-path" class="size-5 phx-click-loading:animate-spin" />
                  Iniciar <.tech_term term={:monte_carlo} aria_describedby_glossary />
                </button>
              <% end %>
              <button
                type="button"
                phx-click="run_simulacao"
                phx-click-loading
                disabled={@simulando || @monte_carlo_ativo}
                class={[
                  "btn gap-2 font-semibold transition-colors",
                  (@simulando || @monte_carlo_ativo) && "btn-disabled",
                  !@simulando && !@monte_carlo_ativo && "btn-primary"
                ]}
              >
                <.icon name="hero-play" class="size-5 phx-click-loading:animate-spin" />
                Rodar simulação
              </button>
            </div>
          </header>

          <%!-- Bloco introdutório: o que é PON, FBEs e Regras --%>
          <section
            class="rounded-xl scada-surface p-4 border border-base-200/50"
            aria-label="O que é PON"
          >
            <p class="text-sm text-base-content/80 leading-relaxed">
              No <.tech_term term={:pon} aria_describedby_glossary show_glossary_link />
              <span class="text-base-content/60"> (Paradigma Orientado a Notificações)</span>, os
              <.tech_term term={:fbe} text="FBEs" aria_describedby_glossary show_glossary_link />
              <span class="text-base-content/60"> (Elementos de Base de Fatos)</span>
              são entidades que representam estado e serviços do domínio: cada atributo notifica apenas as regras que o observam quando seu valor muda; os métodos do FBE são instigados pelas regras. As
              <.tech_term
                term={:regra_pon}
                text="Regras"
                aria_describedby_glossary
                show_glossary_link
              />
              agregam condições (<.tech_term
                term={:premissa_pon}
                text="premissas"
                aria_describedby_glossary
                show_glossary_link
              /> sobre os
              <.tech_term term={:fato_pon} text="fatos" aria_describedby_glossary />) e ações: uma regra só é avaliada quando algum atributo que ela observa notifica uma mudança; se a condição for verdadeira, a ação executa e instiga métodos nos FBEs.
            </p>
          </section>

          <%!-- Zona 1: OEE + lâmpadas de status (artigo §6.1) --%>
          <section
            class="flex flex-wrap items-center gap-4 p-4 rounded-xl scada-surface"
            aria-label="OEE e status"
          >
            <div class="flex items-center gap-3">
              <span class="text-sm font-semibold text-base-content/80">
                <.tech_term term={:oee} aria_describedby_glossary />
              </span>
              <div class="flex items-center gap-2 min-w-[120px]">
                <%= if @oee_percent != nil do %>
                  <span class="text-2xl font-bold tabular-nums">
                    {format_scada_number(@oee_percent)}%
                  </span>
                <% else %>
                  <span class="text-base-content/50 text-sm">—</span>
                <% end %>
              </div>
              <%= if @oee_components != nil do %>
                <div class="flex items-center gap-3 text-xs text-base-content/70 border-l border-base-content/20 pl-3">
                  <span class="inline-flex items-baseline gap-0.5 tabular-nums">
                    <.tech_term term={:oee_availability} text="A" aria_describedby_glossary />: {format_scada_number(
                      (@oee_components[:availability] || 0) * 100
                    )}%
                  </span>
                  <span class="inline-flex items-baseline gap-0.5 tabular-nums">
                    <.tech_term term={:oee_performance} text="P" aria_describedby_glossary />: {format_scada_number(
                      (@oee_components[:performance] || 0) * 100
                    )}%
                  </span>
                  <span class="inline-flex items-baseline gap-0.5 tabular-nums">
                    <.tech_term term={:oee_quality} text="Q" aria_describedby_glossary />: {format_scada_number(
                      (@oee_components[:quality] || 0) * 100
                    )}%
                  </span>
                </div>
              <% end %>
            </div>
            <div class="flex items-center gap-2 border-l border-base-content/20 pl-4">
              <span class="text-xs text-base-content/60">Status</span>
              <span class="flex items-center gap-1.5">
                <span class="size-2.5 rounded-full bg-success animate-pulse" aria-hidden="true">
                </span>
                <span class="text-xs">
                  <.tech_term term={:liveview} text="Conexão" aria_describedby_glossary />
                </span>
              </span>
              <%= if @tsdb_enabled do %>
                <span
                  class="flex items-center gap-1.5"
                  title={if @tsdb_connected == true, do: "TSDB conectado", else: "TSDB desconectado"}
                >
                  <span
                    class={[
                      "size-2.5 rounded-full transition-colors duration-200",
                      @tsdb_connected == true && "bg-success animate-pulse",
                      @tsdb_connected == false && "bg-error",
                      @tsdb_connected != true && @tsdb_connected != false && "bg-base-content/30"
                    ]}
                    aria-hidden="true"
                  >
                  </span>
                  <span class="text-xs">
                    <.tech_term term={:tsdb} aria_describedby_glossary />
                  </span>
                </span>
              <% end %>
              <span
                class="flex items-center gap-1.5"
                title={
                  if @fatos[:fbe_11_grid_fault_detec] == true,
                    do: "Falha na rede detectada",
                    else: "Smart Grid OK"
                }
              >
                <span
                  class={[
                    "size-2.5 rounded-full transition-colors duration-200",
                    @fatos[:fbe_11_grid_fault_detec] == true &&
                      "scada-lamp-critical scada-critical-pulse",
                    @fatos[:fbe_11_grid_fault_detec] != true && "bg-base-content/30"
                  ]}
                  aria-hidden="true"
                >
                </span>
                <span class="text-xs">
                  <.tech_term term={:smart_grid} text="Grid" aria_describedby_glossary />
                </span>
              </span>
            </div>
            <%= if map_size(@ema_control_limits) > 0 do %>
              <div
                class="flex flex-wrap items-center gap-2 border-l border-base-content/20 pl-4 text-xs text-base-content/60"
                title="Limites de controle SPC (3σ)"
              >
                <span class="font-medium">
                  <.tech_term term={:spc} aria_describedby_glossary />
                </span>
                <%= for {nome, lim} <- Enum.take(@ema_control_limits, 4) do %>
                  <span
                    class="font-mono"
                    title={"#{nome}: UCL=#{format_scada_number(lim[:ucl])} LCL=#{format_scada_number(lim[:lcl])}"}
                  >
                    {nome |> to_string()}:
                    <span class="text-info">{format_scada_number(lim[:ucl])}</span>
                    / <span class="text-warning">{format_scada_number(lim[:lcl])}</span>
                  </span>
                <% end %>
              </div>
            <% end %>
          </section>

          <%!-- Zona 2: Grid 11 tiles FBE (artigo §6.1). content-visibility: browser pode pular paint quando fora da viewport. --%>
          <section
            class="scada-section-offscreen grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3"
            aria-label="Tiles por FBE"
          >
            <%= for {fbe_id, nomes} <- @fatos_por_fbe do %>
              <%= if nomes != [] do %>
                <% key_fact = fbe_tile_key_fact(fbe_id) %>
                <% cur_val = key_fact && @fatos[key_fact] %>
                <% delta = key_fact && delta_display(@fatos, @fatos_prev, key_fact, cur_val) %>
                <% {_val, status} = scene_fbe_value_status(fbe_id, @fatos) %>
                <% anomalia? = MapSet.member?(@anomalia_fbes, fbe_id) %>
                <div
                  class={[
                    "scada-tile scada-surface rounded-lg p-3 border border-base-200 transition-colors duration-200",
                    MapSet.member?(@regra_flash_fbes, fbe_id) && "scada-rule-flash",
                    status == :critical && "scada-critical scada-critical-pulse",
                    (status == :warning || anomalia?) && status != :critical && "scada-warning",
                    status == :active && !anomalia? && status != :critical && "scada-surface-hover"
                  ]}
                  role="article"
                  aria-label={"FBE #{fbe_id} #{fbe_descricao(fbe_id)}"}
                >
                  <div class="flex items-center justify-between gap-1">
                    <span class="text-xs font-mono text-base-content/70">
                      <.tech_term
                        term={:fbe}
                        text={"FBE_#{pad2(fbe_id)}"}
                        aria_describedby_glossary
                      />
                    </span>
                    <span class="flex items-center gap-1 shrink-0">
                      <%= if anomalia? do %>
                        <span class="text-warning" aria-label="Anomalia detectada">
                          <.technical_hint title={
                            SimulacoesVisuaisWeb.TechGlossary.entry!(:anomalia_processo).abbr_title
                          }>
                            <.icon name="hero-exclamation-triangle" class="size-4" />
                          </.technical_hint>
                        </span>
                      <% end %>
                      <span
                        class="text-base-content/50 hover:text-base-content/80 cursor-help"
                        title={Map.get(@fbe_descricoes_longas, fbe_id, "")}
                        aria-label="Descrição do FBE"
                      >
                        <.icon name="hero-information-circle" class="size-4" />
                      </span>
                    </span>
                  </div>
                  <div class="font-semibold text-sm mt-0.5">
                    {fbe_descricao(fbe_id) |> String.replace("_", " ")}
                  </div>
                  <div class="mt-2 flex items-baseline gap-2">
                    <span class="font-mono text-sm tabular-nums">{format_scada_number(cur_val)}</span>
                    <%= if delta do %>
                      <span class={[
                        "text-xs font-mono",
                        String.starts_with?(delta, "+") && "scada-delta-up",
                        !String.starts_with?(delta, "+") && "scada-delta-down"
                      ]}>
                        {delta}
                      </span>
                    <% end %>
                  </div>
                  <%!-- Mini gráfico simples (sparkline) em preto e branco --%>
                  <%= if (pts = Map.get(@sparkline_data, fbe_id, [])) != [] do %>
                    <div
                      class="mt-1.5 h-6 w-full min-h-[24px]"
                      aria-hidden="true"
                      title={SimulacoesVisuaisWeb.TechGlossary.entry!(:sparkline).abbr_title}
                    >
                      <svg
                        class="w-full h-full block"
                        viewBox="0 0 80 24"
                        preserveAspectRatio="none"
                        role="img"
                        aria-label={"Sparkline FBE #{fbe_id}"}
                      >
                        <polyline
                          points={sparkline_points(pts, 80, 24)}
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          vector-effect="non-scaling-stroke"
                          class="text-base-content/70"
                        />
                      </svg>
                    </div>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </section>

          <%!-- Tabs: Vista tabela | Vista diagramas | Vista 3D | BI --%>
          <div
            role="tablist"
            aria-label="Modo de visualização"
            class="tabs tabs-boxed bg-base-200/50 p-1 rounded-lg w-fit flex flex-wrap gap-0.5"
          >
            <%= for {mode, label, tab_title} <- @view_modes do %>
              <button
                type="button"
                role="tab"
                aria-selected={@view_mode == mode}
                aria-controls={"panel-#{mode}"}
                id={"tab-#{mode}"}
                title={tab_title}
                phx-click="set_view"
                phx-value-mode={mode}
                class={[
                  "tab tab-sm transition-colors rounded focus-ring",
                  @view_mode == mode && "tab-active"
                ]}
              >
                <%= case mode do %>
                  <% "bi" -> %>
                    <span class="inline-flex flex-wrap items-center gap-x-1 gap-y-0 justify-center">
                      <.tech_term term={:bi} aria_describedby_glossary />
                      <span class="text-base-content/70 font-normal">(painel analítico)</span>
                    </span>
                  <% _ -> %>
                    {label}
                <% end %>
              </button>
            <% end %>
          </div>

          <%!-- Regras (resumo) — R_01 a R_12 (Artigo 05 e 11). content-visibility: otimiza quando fora da viewport. --%>
          <section class="scada-section-offscreen grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
            <%= for {regra_id, title, description} <- @regras_list do %>
              <div
                class="card bg-base-100 shadow-sm border border-base-200"
                title="Nomes em inglês (ex.: diff_pressure, v2g) são atributos dos FBEs no modelo PON. Siglas como AMR, V2G, LMTD, CIP, NR-13 e ISA-88 estão no glossário no final da página."
              >
                <div class="card-body py-3 px-4">
                  <div class="flex items-center gap-2">
                    <span class="badge badge-ghost badge-sm font-mono">R_{pad2(regra_id)}</span>
                    <span class="font-medium text-sm">{title}</span>
                  </div>
                  <p class="text-xs text-base-content/70">
                    {description}
                  </p>
                  <button
                    type="button"
                    phx-click="toggle_regra"
                    phx-value-id={regra_id}
                    class="btn btn-ghost btn-xs mt-1 text-primary gap-1"
                    aria-expanded={@regra_expandida == regra_id}
                  >
                    <.icon
                      name={
                        if @regra_expandida == regra_id,
                          do: "hero-chevron-down",
                          else: "hero-chevron-right"
                      }
                      class="size-3.5"
                    />
                    {if @regra_expandida == regra_id, do: "Ocultar", else: "Como funciona"}
                  </button>
                  <%= if @regra_expandida == regra_id do %>
                    <p class="text-xs text-base-content/70 mt-2 pt-2 border-t border-base-200">
                      {Map.get(@regras_descricoes_longas, regra_id, "")}
                    </p>
                  <% end %>
                </div>
              </div>
            <% end %>
          </section>

          <%!-- Apenas o painel ativo (@view_mode) é renderizado; os outros não entram no DOM, evitando atualizar elementos invisíveis. --%>
          <%= if @view_mode == "3d" do %>
            <%!-- Vista 3D: modelo Digital Twin (JS) · telemetria em tempo real · clique num equipamento para detalhes --%>
            <div
              id="panel-3d"
              role="tabpanel"
              aria-labelledby="tab-3d"
              class="scada-section-offscreen card bg-base-100 shadow-sm border border-base-200 overflow-hidden"
            >
              <div class="card-body p-0">
                <div class="px-4 py-2 border-b border-base-200 flex flex-col gap-1">
                  <div class="flex items-center gap-2">
                    <span class="font-semibold text-sm inline-flex flex-wrap items-baseline gap-x-1 gap-y-0">
                      <span>Vista 3D · Smart Brewery (</span>
                      <.tech_term term={:digital_twin_en} aria_describedby_glossary />
                      <span>)</span>
                    </span>
                    <span class="text-xs text-base-content/70">
                      Arraste para orbitar · roda para zoom · clique num equipamento
                    </span>
                  </div>
                  <span class="text-xs text-base-content/60">
                    Cada objeto tem versão 3D detalhada nos documentos de exemplo; ao selecionar um equipamento, use o botão no painel lateral.
                  </span>
                </div>
                <div class="flex flex-col lg:flex-row gap-0 min-h-[480px]">
                  <div
                    id="scene-3d-wrapper"
                    phx-hook="Scene3D"
                    data-scene-state={Jason.encode!(build_scene_state(assigns))}
                    data-scene-selected={@scene_3d_selected_fbe}
                    class="flex-1 min-h-[480px] relative"
                    role="img"
                    aria-label="Vista 3D do pipeline Smart Brewery. Passe o rato para ver estatísticas; clique para detalhes."
                  >
                    <div
                      id="scene-3d-container"
                      data-scene-container
                      class="w-full min-h-[480px]"
                      phx-update="ignore"
                    >
                    </div>
                    <%= if @scene_3d_hovered_fbe do %>
                      <div class="absolute bottom-4 left-4 right-4 lg:right-auto lg:max-w-sm pointer-events-none z-10">
                        <div class="bg-base-100/95 backdrop-blur-sm border border-base-300 rounded-lg shadow-lg p-3">
                          <p class="font-semibold text-sm text-base-content">
                            {fbe_descricao(@scene_3d_hovered_fbe)}
                            <span class="text-base-content/60 font-mono">
                              FBE_{pad2(@scene_3d_hovered_fbe)}
                            </span>
                          </p>
                          <p class="text-xs text-base-content/60 mt-1">
                            Estatísticas em tempo real (hover)
                          </p>
                          <div class="mt-2 max-h-40 overflow-y-auto">
                            <table class="table table-xs">
                              <tbody>
                                <%= for {fbe_id, nomes} <- @fatos_por_fbe, fbe_id == @scene_3d_hovered_fbe, nome <- nomes do %>
                                  <tr>
                                    <td class="font-mono text-xs py-0.5">
                                      <.technical_hint title={FatoDescriptions.descricao(nome)}>
                                        {attr_label(nome)}
                                      </.technical_hint>
                                    </td>
                                    <td class="text-right font-mono text-xs py-0.5">
                                      {format_value(@fatos[nome])}
                                    </td>
                                  </tr>
                                <% end %>
                              </tbody>
                            </table>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                  <%= if @scene_3d_selected_fbe do %>
                    <.fbe_detail_panel
                      part={:sidebar}
                      id="fbe-detail-3d-wrapper"
                      fbe_heading={"Detalhe FBE_#{pad2(@scene_3d_selected_fbe)}"}
                      fbe_label={fbe_descricao(@scene_3d_selected_fbe)}
                      fbe_descricao_long={Map.get(@fbe_descricoes_longas, @scene_3d_selected_fbe, "")}
                      rows={fbe_detail_rows(assigns, @scene_3d_selected_fbe)}
                      selected_fbe={@scene_3d_selected_fbe}
                      iframe_facts={fbe_facts_for_iframe(assigns)}
                      static_3d_url={Map.get(@fbe_static_3d_url, @scene_3d_selected_fbe)}
                    />
                  <% end %>
                </div>
                <%= if @scene_3d_selected_fbe && Map.get(@fbe_static_3d_url, @scene_3d_selected_fbe) do %>
                  <.fbe_detail_panel
                    part={:iframe}
                    id="fbe-detail-3d-wrapper"
                    fbe_heading={"Detalhe FBE_#{pad2(@scene_3d_selected_fbe)}"}
                    fbe_label={fbe_descricao(@scene_3d_selected_fbe)}
                    rows={fbe_detail_rows(assigns, @scene_3d_selected_fbe)}
                    selected_fbe={@scene_3d_selected_fbe}
                    iframe_facts={fbe_facts_for_iframe(assigns)}
                    static_3d_url={Map.get(@fbe_static_3d_url, @scene_3d_selected_fbe)}
                  />
                <% end %>
              </div>
            </div>
          <% else %>
            <%= if @view_mode == "bi" do %>
              <%!-- Aba BI nativa (sem iframe): OEE, séries, CEP, correlação, sinótico, eventos. --%>
              <div
                id="panel-bi"
                role="tabpanel"
                aria-labelledby="tab-bi"
                class="scada-section-offscreen space-y-4"
              >
                <div class="card bg-base-100 shadow-sm border border-base-200">
                  <div class="card-body">
                    <div class="flex flex-wrap items-center justify-between gap-2">
                      <h2 class="card-title text-base flex flex-wrap items-baseline gap-x-2 gap-y-1">
                        <.tech_term term={:bi} aria_describedby_glossary />
                        <span class="text-base-content/50 font-normal">Nativo · Smart Brewery</span>
                      </h2>
                      <span class="text-xs text-base-content/60 inline-flex flex-wrap items-baseline gap-x-1">
                        <span>Dashboard em</span>
                        <.tech_term term={:liveview} aria_describedby_glossary />
                        <span>(sem iframe)</span>
                      </span>
                    </div>
                    <.form for={@bi_form} id="bi-filters-form" phx-change="bi_filters_change">
                      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                        <.input
                          field={@bi_form[:window]}
                          type="select"
                          label="Janela"
                          options={[
                            {"Últimas 6h", "6h"},
                            {"Últimas 24h", "24h"},
                            {"Últimos 7d", "7d"},
                            {"Últimos 30d", "30d"}
                          ]}
                        />
                        <.input
                          field={@bi_form[:granularity]}
                          type="select"
                          label="Granularidade"
                          options={[
                            {"1 minuto", "1min"},
                            {"1 hora", "1h"},
                            {"1 dia", "1day"}
                          ]}
                        />
                        <.input
                          field={@bi_form[:fbe_id]}
                          type="select"
                          label="Equipamento (FBE)"
                          options={[{"Todos", "all"} | @bi_options.fbe]}
                        />
                        <.input
                          field={@bi_form[:fact_name]}
                          type="select"
                          label="Variável"
                          options={[{"Todas", "all"} | @bi_options.facts]}
                        />
                      </div>
                    </.form>
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-3">
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body py-3">
                      <div class="text-xs text-base-content/60">
                        <.tech_term term={:oee} aria_describedby_glossary /> (atual)
                      </div>
                      <div class="text-2xl font-bold tabular-nums">
                        {format_scada_number(@bi_data.oee_cards.latest.oee)}%
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body py-3">
                      <div class="text-xs text-base-content/60">
                        <.tech_term
                          term={:oee_availability}
                          text="Disponibilidade (A)"
                          aria_describedby_glossary
                        />
                      </div>
                      <div class="text-xl font-semibold tabular-nums">
                        {format_scada_number(@bi_data.oee_cards.latest.availability)}%
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body py-3">
                      <div class="text-xs text-base-content/60">
                        <.tech_term
                          term={:oee_performance}
                          text="Performance (P)"
                          aria_describedby_glossary
                        />
                      </div>
                      <div class="text-xl font-semibold tabular-nums">
                        {format_scada_number(@bi_data.oee_cards.latest.performance)}%
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body py-3">
                      <div class="text-xs text-base-content/60">
                        <.tech_term
                          term={:oee_quality}
                          text="Qualidade (Q)"
                          aria_describedby_glossary
                        />
                      </div>
                      <div class="text-xl font-semibold tabular-nums">
                        {format_scada_number(@bi_data.oee_cards.latest.quality)}%
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body py-3">
                      <div class="text-xs text-base-content/60">
                        <.tech_term
                          term={:anomalia_processo}
                          text="Anomalias"
                          aria_describedby_glossary
                        />
                      </div>
                      <div class="text-xl font-semibold tabular-nums">
                        {@bi_data.totals.anomalies}
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body py-3">
                      <div class="text-xs text-base-content/60">
                        <.tech_term
                          term={:regra_pon}
                          text="Regras disparadas"
                          aria_describedby_glossary
                        />
                      </div>
                      <div class="text-xl font-semibold tabular-nums">
                        {@bi_data.totals.rules}
                      </div>
                    </div>
                  </div>
                </div>

                <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h3 class="font-semibold text-sm inline-flex flex-wrap items-baseline gap-x-2">
                        <span>Tendência</span>
                        <.tech_term term={:oee} aria_describedby_glossary />
                      </h3>
                      <p class="text-xs text-base-content/60 inline-flex flex-wrap items-baseline gap-x-1">
                        <.tech_term term={:oee} aria_describedby_glossary />
                        <span>e componentes (</span>
                        <.tech_term term={:oee_availability} text="A" aria_describedby_glossary />
                        <span>/</span>
                        <.tech_term term={:oee_performance} text="P" aria_describedby_glossary />
                        <span>/</span>
                        <.tech_term term={:oee_quality} text="Q" aria_describedby_glossary />
                        <span>)</span>
                      </p>
                      <div
                        id="bi-d3-chart-oee"
                        class="h-44 mt-2 w-full"
                        phx-update="ignore"
                        phx-hook="D3BiChart"
                        data-payload={Jason.encode!(bi_d3_oee_payload(@bi_data.oee_trend))}
                      >
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h3 class="font-semibold text-sm inline-flex flex-wrap items-baseline gap-x-2">
                        <.tech_term
                          term={:serie_temporal_telemetria}
                          text="Série temporal"
                          aria_describedby_glossary
                        />
                        <span>de telemetria</span>
                      </h3>
                      <p class="text-xs text-base-content/60 inline-flex flex-wrap items-baseline gap-x-1">
                        <span>Fonte agregada por granularidade selecionada (</span>
                        <.tech_term term={:tsdb} aria_describedby_glossary />
                        <span>)</span>
                      </p>
                      <div
                        id="bi-d3-chart-telemetry"
                        class="h-44 mt-2 w-full"
                        phx-update="ignore"
                        phx-hook="D3BiChart"
                        data-payload={
                          Jason.encode!(bi_d3_telemetry_payload(@bi_data.telemetry_trend))
                        }
                      >
                      </div>
                    </div>
                  </div>
                </div>

                <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h3 class="font-semibold text-sm inline-flex flex-wrap items-baseline gap-x-2">
                        <.tech_term term={:cep_ichart} aria_describedby_glossary />
                        <span class="text-base-content/70 font-normal">(</span>
                        <.tech_term term={:amr} aria_describedby_glossary />
                        <span class="text-base-content/70 font-normal">)</span>
                      </h3>
                      <p class="text-xs text-base-content/60 inline-flex flex-wrap items-baseline gap-x-1">
                        <.tech_term term={:cl_spc} text="CL" aria_describedby_glossary />
                        <span>/</span>
                        <.tech_term term={:ucl} aria_describedby_glossary />
                        <span>/</span>
                        <.tech_term term={:lcl} aria_describedby_glossary />
                        <span>calculados no backend</span>
                      </p>
                      <div class="space-y-1 text-xs text-base-content/70">
                        <div>
                          <.tech_term term={:cl_spc} text="CL" aria_describedby_glossary />: {format_scada_number(
                            @bi_data.cep_chart.cl
                          )}
                        </div>
                        <div>
                          <.tech_term term={:ucl} aria_describedby_glossary />: {format_scada_number(
                            @bi_data.cep_chart.ucl
                          )}
                        </div>
                        <div>
                          <.tech_term term={:lcl} aria_describedby_glossary />: {format_scada_number(
                            @bi_data.cep_chart.lcl
                          )}
                        </div>
                      </div>
                      <div
                        id="bi-d3-chart-cep"
                        class="h-44 mt-2 w-full"
                        phx-update="ignore"
                        phx-hook="D3BiChart"
                        data-payload={Jason.encode!(bi_d3_cep_payload(@bi_data.cep_chart))}
                      >
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h3 class="font-semibold text-sm inline-flex flex-wrap items-baseline gap-x-2">
                        <.tech_term
                          term={:correlacao_fisica}
                          text="Correlação física"
                          aria_describedby_glossary
                        />
                        <span class="text-base-content/70 font-normal">(Darcy / Fermentação)</span>
                      </h3>
                      <p class="text-xs text-base-content/60">
                        Pontos: pressão, claridade, bomba, Brix, CO2, pH
                      </p>
                      <div class="overflow-x-auto">
                        <table class="table table-xs table-zebra">
                          <thead>
                            <tr>
                              <th>Pressão</th>
                              <th>Claridade</th>
                              <th>Bomba</th>
                              <th>Brix</th>
                              <th>CO2</th>
                              <th>pH</th>
                            </tr>
                          </thead>
                          <tbody>
                            <%= for row <- Enum.take(@bi_data.correlation_points, -12) do %>
                              <tr>
                                <td>{format_scada_number(row.pressure)}</td>
                                <td>{format_scada_number(row.clarity)}</td>
                                <td>{format_scada_number(row.pump)}</td>
                                <td>{format_scada_number(row.brix)}</td>
                                <td>{format_scada_number(row.co2)}</td>
                                <td>{format_scada_number(row.ph)}</td>
                              </tr>
                            <% end %>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="grid grid-cols-1 xl:grid-cols-2 gap-4">
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h3 class="font-semibold text-sm">
                        <.tech_term term={:painel_sinotico} aria_describedby_glossary />
                      </h3>
                      <p class="text-xs text-base-content/60 inline-flex flex-wrap items-baseline gap-x-1">
                        <span>Estado simplificado por</span>
                        <.tech_term term={:fbe} aria_describedby_glossary />
                        <span>(ok/warning)</span>
                      </p>
                      <div class="grid grid-cols-2 sm:grid-cols-3 gap-2 mt-2">
                        <%= for s <- @bi_data.synoptic_status do %>
                          <div class={[
                            "rounded border p-2 text-xs",
                            s.status == :warning && "border-warning bg-warning/10",
                            s.status == :ok && "border-success bg-success/10",
                            s.status == :unknown && "border-base-300 bg-base-200"
                          ]}>
                            <div class="font-mono">{s.fbe_id}</div>
                            <div>Média: {format_scada_number(s.avg_value)}</div>
                            <div>Máx: {format_scada_number(s.max_value)}</div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h3 class="font-semibold text-sm inline-flex flex-wrap items-baseline gap-x-2">
                        <span>Eventos (</span>
                        <.tech_term term={:diagrama_pareto} text="Pareto" aria_describedby_glossary />
                        <span>e Top</span>
                        <.tech_term term={:regra_pon} text="Regras" aria_describedby_glossary />
                        <span>)</span>
                      </h3>
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2">
                        <div>
                          <p class="text-xs text-base-content/60 mb-1">Top anomalias</p>
                          <%= for item <- @bi_data.anomaly_pareto do %>
                            <div class="mb-1.5">
                              <div class="flex justify-between text-xs">
                                <span class="font-mono">{item.label}</span>
                                <span>{item.total}</span>
                              </div>
                              <progress
                                class="progress progress-warning w-full"
                                value={item.total}
                                max={bi_max_total(@bi_data.anomaly_pareto)}
                              >
                              </progress>
                            </div>
                          <% end %>
                        </div>
                        <div>
                          <p class="text-xs text-base-content/60 mb-1">Top regras disparadas</p>
                          <%= for item <- @bi_data.rule_top do %>
                            <div class="mb-1.5">
                              <div class="flex justify-between text-xs">
                                <span class="font-mono">{item.label}</span>
                                <span>{item.total}</span>
                              </div>
                              <progress
                                class="progress progress-info w-full"
                                value={item.total}
                                max={bi_max_total(@bi_data.rule_top)}
                              >
                              </progress>
                            </div>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% else %>
              <%= if @view_mode == "diagramas" do %>
                <%!-- Vista diagramas: Grafo PON + Pipeline --%>
                <div
                  id="panel-diagramas"
                  role="tabpanel"
                  aria-labelledby="tab-diagramas"
                  class="scada-section-offscreen grid grid-cols-1 lg:grid-cols-2 gap-6"
                >
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h2 class="card-title text-base inline-flex flex-wrap items-baseline gap-x-2">
                        <span>Grafo da malha</span>
                        <.tech_term term={:pon} aria_describedby_glossary />
                      </h2>
                      <p class="text-xs text-base-content/70 inline-flex flex-wrap items-baseline gap-x-1">
                        <.tech_term term={:regra_pon} text="Regras" aria_describedby_glossary />
                        <span>e</span>
                        <.tech_term term={:fbe} text="FBEs" aria_describedby_glossary />
                        <span>: observa / aciona</span>
                      </p>
                      <div
                        id="mermaid-grafo-pon"
                        phx-hook="Mermaid"
                        data-mermaid-source={build_mermaid_grafo_pon(assigns)}
                        class="min-h-[280px] overflow-auto"
                      >
                        <div
                          id="mermaid-grafo-pon-container"
                          data-mermaid-container
                          class="mermaid-container"
                          phx-update="ignore"
                        >
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="card bg-base-100 shadow-sm border border-base-200">
                    <div class="card-body">
                      <h2 class="card-title text-base">Pipeline da cervejaria</h2>
                      <p class="text-xs text-base-content/70">
                        Fluxo do processo · valores em tempo real
                      </p>
                      <div
                        id="mermaid-pipeline"
                        phx-hook="Mermaid"
                        data-mermaid-source={build_mermaid_pipeline(assigns)}
                        class="min-h-[280px] overflow-auto"
                      >
                        <div
                          id="mermaid-pipeline-container"
                          data-mermaid-container
                          class="mermaid-container"
                          phx-update="ignore"
                        >
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              <% else %>
                <%!-- Vista tabela: Terminal + FBEs em layout responsivo --%>
                <div
                  id="panel-tabela"
                  role="tabpanel"
                  aria-labelledby="tab-tabela"
                  class="scada-section-offscreen grid grid-cols-1 xl:grid-cols-3 gap-6"
                >
                  <%!-- Terminal: 1 coluna em xl ocupa 1/3 --%>
                  <section class="xl:col-span-1 flex flex-col">
                    <div class="card bg-base-100 shadow-sm border border-base-200 flex-1 flex flex-col min-h-[320px]">
                      <div class="card-body flex-1 flex flex-col min-h-0 p-0">
                        <div class="px-4 py-3 border-b border-base-200 flex items-center justify-between shrink-0">
                          <div class="flex items-center gap-2">
                            <.icon name="hero-queue-list" class="size-5 text-base-content/60" />
                            <h2 class="font-semibold text-sm">Eventos / notificações</h2>
                          </div>
                          <span
                            class="badge badge-ghost badge-sm"
                            title={"Máximo #{@max_log_entries} entradas"}
                          >
                            {@event_log_count} eventos
                            <span class="opacity-70">/ #{@max_log_entries}</span>
                          </span>
                        </div>
                        <div
                          id="event-log-terminal"
                          class="flex-1 overflow-y-auto overflow-x-hidden p-4 bg-neutral font-mono text-xs text-neutral-content min-h-[240px] rounded-b-2xl scroll-smooth"
                          role="log"
                          aria-label="Log de eventos em tempo real"
                        >
                          <div id="event-log" phx-update="stream" class="contents">
                            <div
                              id="event-log-empty"
                              class="hidden only:block text-neutral-content/50 text-xs py-4"
                            >
                              Nenhum evento ainda.
                            </div>
                            <div
                              :for={{id, entry} <- @streams.event_log}
                              id={id}
                              class="event-log-entry flex flex-wrap gap-x-2 gap-y-0.5 py-1 border-b border-neutral-content/10 last:border-0"
                            >
                              <span class="text-neutral-content/50 shrink-0">{entry.at}</span>
                              <span class={
                                if entry.type == "fato", do: "text-green-400", else: "text-sky-300"
                              }>
                                {entry.type}
                              </span>
                              <span class="break-all">{entry.msg}</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </section>

                  <%!-- FBEs: 2 colunas em xl, scroll --%>
                  <section class="xl:col-span-2 space-y-3">
                    <h2 class="text-lg font-semibold text-base-content flex flex-wrap items-center gap-2">
                      <.icon name="hero-cube" class="size-5 text-base-content/70" />
                      <span class="inline-flex flex-wrap items-baseline gap-x-2">
                        <span>Elementos da base de fatos (</span>
                        <.tech_term
                          term={:fbe}
                          text="FBEs"
                          aria_describedby_glossary
                          show_glossary_link
                        />
                        <span>)</span>
                      </span>
                    </h2>
                    <div class="space-y-3 max-h-[calc(100vh-12rem)] overflow-y-auto pr-1">
                      <%= for {fbe_id, nomes} <- @fatos_por_fbe do %>
                        <%= if nomes != [] do %>
                          <div class="collapse collapse-arrow bg-base-100 shadow-sm border border-base-200 rounded-xl">
                            <input
                              type="checkbox"
                              name={"fbe-#{fbe_id}"}
                              checked={MapSet.member?(@open_fbes, fbe_id)}
                              class="pointer-events-none"
                              tabindex="-1"
                              aria-hidden="true"
                            />
                            <div
                              class="collapse-title min-h-0 py-3 px-4 font-medium flex items-center gap-2 cursor-pointer"
                              role="button"
                              tabindex="0"
                              phx-click="toggle_fbe"
                              phx-value-id={fbe_id}
                            >
                              <span class="badge badge-outline badge-sm font-mono">
                                FBE_{pad2(fbe_id)}
                              </span>
                              <span>{fbe_descricao(fbe_id)}</span>
                              <span class="badge badge-ghost badge-sm ml-auto">
                                {length(nomes)} fatos
                              </span>
                            </div>
                            <div class="collapse-content">
                              <%= if (desc_long = Map.get(@fbe_descricoes_longas, fbe_id)) != nil do %>
                                <p class="text-xs text-base-content/70 mb-3 px-4 pt-2">
                                  {desc_long}
                                </p>
                              <% end %>
                              <div class="overflow-x-auto px-4 pb-4">
                                <table class="table table-sm table-zebra">
                                  <caption class="sr-only">
                                    Atributos do FBE_{pad2(fbe_id)} em tempo real: nome técnico, descrição e valor atual.
                                  </caption>
                                  <thead>
                                    <tr>
                                      <th scope="col" class="font-mono text-xs">
                                        Atributo
                                      </th>
                                      <th scope="col" class="text-xs font-medium">
                                        Descrição
                                      </th>
                                      <th scope="col" class="text-right font-mono text-xs">
                                        Valor
                                      </th>
                                    </tr>
                                  </thead>
                                  <tbody>
                                    <%= for nome <- nomes do %>
                                      <tr>
                                        <th
                                          scope="row"
                                          class="font-mono text-xs font-normal align-top"
                                        >
                                          <.technical_hint title={FatoDescriptions.descricao(nome)}>
                                            {attr_label(nome)}
                                          </.technical_hint>
                                        </th>
                                        <td class="text-xs text-base-content/70 align-top max-w-md">
                                          {FatoDescriptions.descricao(nome)}
                                        </td>
                                        <td class="text-right align-top">
                                          <span class="font-mono text-xs badge badge-ghost badge-sm">
                                            {format_value(@fatos[nome])}
                                          </span>
                                        </td>
                                      </tr>
                                    <% end %>
                                  </tbody>
                                </table>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </section>
                </div>
              <% end %>
            <% end %>
          <% end %>

          <.glossary_section terms={SimulacoesVisuaisWeb.TechGlossary.terms_for(:smart_brewery)} />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
