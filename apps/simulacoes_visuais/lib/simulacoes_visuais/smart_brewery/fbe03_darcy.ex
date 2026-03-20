defmodule SimulacoesVisuais.SmartBrewery.FBE03Darcy do
  @moduledoc """
  Modelo físico Lei de Darcy para FBE_03 (Tina de Filtro). Alinhado ao artigo 12
  (Fundamentações Indústria 4.0: dinâmica de fluidos e separação sólido-líquido).

  - **Lei de Darcy**: ΔP = (Q·μ·L)/(k·A). A taxa volumétrica de fluxo é proporcional
    ao gradiente de pressão e inversamente proporcional à resistência (permeabilidade k).
  - **Torta compressível**: a permeabilidade k decai com o escoamento e compactação do
    leito (ODE: dk/dt = -α·k·Q, integrada por Euler). O artigo 12 descreve a resistência
    total R = R_m + α·w (meio filtrante + torta); aqui k equivale a 1/R efetivo.
  - **Porosidade**: a queda de k simula a redução de porosidade (ε) sob pressão; a
    relação Kozeny-Carman (α ∝ (1-ε)²/ε³) está implícita no decaimento de k com Q.
  - **Rake**: a ação R_01 (lower_rake_position) restaura k ao descer o rake, recompondo
    microestrutura e mitigando stuck mash (artigo 12).
  - Valida RegraOtimizacaoFiltracao (R_01) quando diff_pressure > 150 mbar,
    wort_clarity < 20 e pump_speed > 50.
  """

  use GenServer

  alias Tec0301Pon.PON.Fato

  require Logger

  # Constantes geométricas (escala adimensional para ΔP em mbar)
  @l 1.0
  @a 1.0
  @k_min 0.15
  @k_max 1.5
  @rake_restore 0.12
  # ODE: dk/dt = -α·k·Q → solução k(t)=k0*exp(-α*Q*t). Por tick (t=1): k_new = k*exp(-α*Q). Artigo 06: decaimento quase exponencial.
  @alpha_ode 0.0004
  # Viscosidade μ: maior quando sparge_water_temp menor (água fria mais viscosa);
  # artigo: μ aumenta com extração/gravidade — proxy via k (k baixo = mais retenção)
  @mu_base 0.9
  @mu_temp_factor 0.02
  @mu_k_factor 0.08

  # Estado como tupla etiquetada `{:fbe03_darcy, k, prev_rake_height, t_flow}` — menos overhead
  # que mapa pequeno no heap do processo (POC alinhado a docs de desempenho).
  @state_tag :fbe03_darcy

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Avança um tick: lê PON, atualiza k (ODE), calcula ΔP e wort_clarity e escreve fatos."
  def tick do
    GenServer.cast(__MODULE__, :tick)
  end

  @impl true
  def init(:ok) do
    {:ok, {@state_tag, 1.0, 50, 0.0}}
  end

  @impl true
  def handle_cast(:tick, {@state_tag, k, prev_rake, t_flow}) do
    pump_speed = safe_obter_number(:fbe_03_pump_speed, 40)
    sparge_temp = safe_obter_number(:fbe_03_sparge_water_temp, 75)
    rake_height = safe_obter_number(:fbe_03_rake_height, 50)

    # Vazão proporcional à velocidade da bomba
    q = max(1, pump_speed)

    # μ decai com temperatura; aumenta com retenção (k baixo = mais extração/gravidade)
    mu_temp = @mu_base + (75 - sparge_temp) * @mu_temp_factor
    mu = mu_temp * (1.0 + (1.5 - k) * @mu_k_factor)
    mu = max(0.5, min(1.5, mu))

    # Tempo efetivo de escoamento (integral de fluxo normalizado)
    t_flow_new = t_flow + q / 50.0

    # Decaimento exponencial: k_after_decay = k * exp(-α*Q) (artigo 06)
    k_after_decay = k * :math.exp(-@alpha_ode * q)
    k_after_decay = max(@k_min, k_after_decay)

    # Restauração quando rake desce (ação R_01 lower_rake_position)
    rake_drop = prev_rake - rake_height
    k_new = if rake_drop > 2, do: k_after_decay + @rake_restore, else: k_after_decay
    k_new = max(@k_min, min(@k_max, k_new))

    # Lei de Darcy: ΔP = (Q · μ · L) / (k · A)
    diff_pressure = q * mu * @l / (k_new * @a)
    diff_pressure = round(max(40, min(200, diff_pressure)))

    # Clareza inversamente ligada a carreamento (k baixo = mais retenção = pior clareza)
    wort_clarity = round(k_new * 45)
    wort_clarity = max(5, min(80, wort_clarity))

    try do
      Fato.atualizar(:fbe_03_diff_pressure, diff_pressure)
      Fato.atualizar(:fbe_03_wort_clarity, wort_clarity)
    rescue
      e -> Logger.warning("[FBE03Darcy] Falha ao atualizar fatos: #{inspect(e)}")
    end

    {:noreply, {@state_tag, k_new, rake_height, t_flow_new}}
  end

  defp safe_obter_number(nome, default) do
    try do
      v = Fato.obter(nome)

      case v do
        n when is_integer(n) -> n
        n when is_float(n) -> round(n)
        _ -> default
      end
    rescue
      _ -> default
    end
  end
end
