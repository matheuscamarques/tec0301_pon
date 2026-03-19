defmodule Tec0301Pon.Examples.AlarmeSimples do
  @moduledoc """
  Exemplo replicado dos recursos PON: **Alarme monitorado** (Ronszcka 2019, Wiecheteck 2011).

  Cenário: central de alarme (ligado/desligado) + sensor (anomalia). Regra: se alarme ligado
  e sensor detectou anomalia → disparar sirene e notificar usuários.

  Regras definidas via DSL em `AlarmeSimples.Regras`.
  Execute com: mix run examples/alarme_simples_simulacao.exs
  """
  alias Tec0301Pon.PON.Fato

  def start_link do
    Fato.start_link(:alarme_ligado, false)
    Fato.start_link(:sensor_anomalia, false)
    Tec0301Pon.Examples.AlarmeSimples.Regras.RegraAlarmeMonitorado.start_link()
    {:ok, self()}
  end

  def simular do
    IO.puts("--- Alarme simples (exemplo dos recursos PON) ---")
    Process.sleep(500)

    IO.puts("\n[Usuário] Armando o alarme.")
    Fato.atualizar(:alarme_ligado, true)
    Process.sleep(500)

    IO.puts("[Sensor] Anomalia detectada.")
    Fato.atualizar(:sensor_anomalia, true)
    Process.sleep(500)
  end
end
