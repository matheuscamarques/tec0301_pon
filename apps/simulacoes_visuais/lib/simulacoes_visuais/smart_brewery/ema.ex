defmodule SimulacoesVisuais.SmartBrewery.EMA do
  @moduledoc """
  Média móvel exponencial (EMA/EWMA) e detecção de anomalia (artigo 07 §5.1 e artigo 12 SPC).

  Mantém por fato: EMA, desvio padrão amostral, **UCL/LCL** (limites de controle μ ± 3σ) e **CL** (linha central).
  Emite evento no PubSub `smart_brewery:anomalias` quando detecta anomalia.

  **Regras de detecção (configuráveis):**
  - **3-Sigma (padrão):** um ponto fora de UCL ou LCL.
  - **Western Electric:** N pontos consecutivos fora de 3σ (reduz falsos positivos), ou um ponto além de 4σ.
  """

  use GenServer

  require Logger

  @topic_anomalias "smart_brewery:anomalias"
  @default_alpha 0.2
  @window_size 30
  @sigma_mult 3.0
  @sigma_mult_4 4.0
  @western_n_consecutive 4

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Registra um valor para um fato; atualiza EMA/sigma e pode emitir anomalia."
  def push(nome_fato, valor) when is_atom(nome_fato) and is_number(valor) do
    GenServer.cast(__MODULE__, {:push, nome_fato, valor})
  end

  @doc "Retorna o estado atual por fato (EMA, sigma, UCL, LCL, CL, anomaly, etc.) para o painel."
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc "Retorna os limites de controle por fato: %{fact_name => %{ucl, lcl, cl, ema, sigma}}."
  def get_control_limits do
    GenServer.call(__MODULE__, :get_control_limits)
  end

  @impl true
  def init(opts) do
    alpha = Keyword.get(opts, :alpha) || @default_alpha

    use_western =
      Keyword.get(opts, :western_electric) ||
        Application.get_env(:simulacoes_visuais, :ema_western_electric, false)

    n_consec =
      Keyword.get(opts, :western_n_consecutive) ||
        Application.get_env(
          :simulacoes_visuais,
          :ema_western_n_consecutive,
          @western_n_consecutive
        )

    state = %{
      alpha: alpha,
      western_electric: use_western,
      western_n_consecutive: n_consec,
      per_fact: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:push, nome_fato, valor}, state) do
    per_fact =
      Map.update(state.per_fact, nome_fato, init_fact(valor), fn fact ->
        update_fact(fact, valor, state.alpha, state.western_electric, state.western_n_consecutive)
      end)

    fact = per_fact[nome_fato]

    if fact.anomaly do
      Phoenix.PubSub.broadcast(
        SimulacoesVisuais.PubSub,
        @topic_anomalias,
        {:anomalia, nome_fato, valor, fact.ema, fact.sigma}
      )

      Logger.debug(
        "[EMA] Anomalia #{nome_fato}: valor=#{valor}, EMA=#{fact.ema}, 3*sigma=#{3 * fact.sigma}"
      )
    end

    {:noreply, %{state | per_fact: per_fact}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    reply = enrich_per_fact_with_limits(state.per_fact)
    {:reply, reply, state}
  end

  @impl true
  def handle_call(:get_control_limits, _from, state) do
    limits =
      state.per_fact
      |> Enum.map(fn {name, f} ->
        {name,
         %{
           ucl: f.ema + @sigma_mult * f.sigma,
           lcl: f.ema - @sigma_mult * f.sigma,
           cl: f.ema,
           ema: f.ema,
           sigma: f.sigma
         }}
      end)
      |> Map.new()

    {:reply, limits, state}
  end

  defp enrich_per_fact_with_limits(per_fact) do
    Enum.into(per_fact, %{}, fn {name, f} ->
      {name,
       Map.merge(f, %{
         ucl: f.ema + @sigma_mult * f.sigma,
         lcl: f.ema - @sigma_mult * f.sigma,
         cl: f.ema
       })}
    end)
  end

  defp init_fact(valor) do
    %{
      ema: valor,
      variance: 0.0,
      sigma: 0.0,
      samples: [valor],
      anomaly: false,
      consecutive_out: 0
    }
  end

  defp update_fact(fact, valor, alpha, western, n_consec) do
    new_ema = alpha * valor + (1 - alpha) * fact.ema
    new_samples = [valor | fact.samples] |> Enum.take(@window_size)
    sigma = std_dev(new_samples, new_ema)

    out_3sigma = sigma > 0 and abs(valor - new_ema) > @sigma_mult * sigma
    out_4sigma = sigma > 0 and abs(valor - new_ema) > @sigma_mult_4 * sigma

    consecutive_new = if out_3sigma, do: (fact.consecutive_out || 0) + 1, else: 0

    anomaly =
      if western do
        out_4sigma or consecutive_new >= n_consec
      else
        out_3sigma
      end

    %{
      ema: new_ema,
      variance: variance(new_samples, new_ema),
      sigma: sigma,
      samples: new_samples,
      anomaly: anomaly,
      consecutive_out: consecutive_new
    }
  end

  defp variance(samples, mean) when length(samples) >= 2 do
    n = length(samples)
    sum_sq = Enum.reduce(samples, 0, fn x, acc -> acc + (x - mean) * (x - mean) end)
    sum_sq / (n - 1)
  end

  defp variance(_, _), do: 0.0

  defp std_dev(samples, mean) do
    variance(samples, mean) |> :math.sqrt()
  end
end
