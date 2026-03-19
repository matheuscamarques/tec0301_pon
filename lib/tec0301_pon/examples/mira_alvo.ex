defmodule Tec0301Pon.Examples.MiraAlvo do
  @moduledoc """
  PoC: **Mira ao Alvo** (Santos 2017, Ferreira 2015, Ronszcka 2019).

  Cenário simplificado: alvo detectado + mira alinhada → disparo autorizado.

  Regras definidas via DSL em `MiraAlvo.Regras`.
  Execute: mix run examples/mira_alvo_simulacao.exs
  """
  alias Tec0301Pon.PON.Fato

  def start_link do
    Fato.start_link(:mira_alvo_detectado, false)
    Fato.start_link(:mira_alinhada, false)
    Tec0301Pon.Examples.MiraAlvo.Regras.RegraDisparo.start_link()
    {:ok, self()}
  end

  def simular do
    IO.puts("--- Mira ao Alvo (PoC) ---")
    Process.sleep(400)

    IO.puts("\n[Sensor] Alvo detectado.")
    Fato.atualizar(:mira_alvo_detectado, true)
    Process.sleep(400)

    IO.puts("[Sistema] Mira alinhada.")
    Fato.atualizar(:mira_alinhada, true)
    Process.sleep(500)
  end
end
