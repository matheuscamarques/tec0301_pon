defmodule Tec0301Pon.Examples.AlarmeCorrelacao do
  @moduledoc """
  PoC: **Alarme por correlação de sensores** (Ronszcka 2019, Kerschbaumer 2018).

  Três premissas (AND): Sensor Temperatura acionado, Sensor Presença acionado, Alarme ativo.
  Se as três forem verdadeiras → ativar alarme (ex.: por 60s) e notificar.

  Regras definidas via DSL em `AlarmeCorrelacao.Regras`.
  Execute: mix run examples/alarme_correlacao_simulacao.exs
  """
  alias Tec0301Pon.PON.Fato

  def start_link do
    Fato.start_link(:alarme_corr_sensor_temp, false)
    Fato.start_link(:alarme_corr_sensor_presenca, false)
    Fato.start_link(:alarme_corr_sistema_ativo, false)
    Tec0301Pon.Examples.AlarmeCorrelacao.Regras.RegraCorrelacao.start_link()
    {:ok, self()}
  end

  def simular do
    IO.puts("--- Alarme por correlação de sensores ---")
    Process.sleep(400)

    IO.puts("\n[Sensor] Temperatura alta detectada.")
    Fato.atualizar(:alarme_corr_sensor_temp, true)
    Process.sleep(400)

    IO.puts("[Sensor] Presença detectada.")
    Fato.atualizar(:alarme_corr_sensor_presenca, true)
    Process.sleep(400)

    IO.puts("[Sistema] Alarme ativado pelo usuário.")
    Fato.atualizar(:alarme_corr_sistema_ativo, true)
    Process.sleep(500)
  end
end
