defmodule Tec0301Pon.Examples.PortaoEletronico do
  @moduledoc """
  PoC: **Portão eletrônico** (Wiecheteck 2011).

  Fatos: comando_abrir, sensor_obstaculo, portao_aberto.
  Regra: se comando_abrir e não há obstáculo → acionar abertura (adapter) e atualizar estado.

  Regras definidas via DSL em `PortaoEletronico.Regras`.
  Execute: mix run examples/portao_eletronico_simulacao.exs
  """
  alias Tec0301Pon.PON.Fato

  def start_link do
    Fato.start_link(:portao_comando_abrir, false)
    Fato.start_link(:portao_sensor_obstaculo, false)
    Fato.start_link(:portao_aberto, false)
    Tec0301Pon.Examples.PortaoEletronico.Regras.RegraAbrirPortao.start_link()
    {:ok, self()}
  end

  def simular do
    IO.puts("--- Portão eletrônico (PoC) ---")
    Process.sleep(400)

    IO.puts("\n[Usuário] Acionando abertura.")
    Fato.atualizar(:portao_comando_abrir, true)
    Process.sleep(500)
  end
end
