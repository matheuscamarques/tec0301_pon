defmodule Tec0301Pon.Examples.PredioInteligente do
  @moduledoc """
  Cenário Prédio Inteligente: fatos base (temp, ocupação, hora, alarme, porta, CO2),
  fatos inferidos (luz_sala_ligada, modo_emergencia) e regras em cascata com prioridade
  segurança > conforto. Reutiliza AlarmeIO e adapters PredioIO.

  Regras definidas via DSL em `PredioInteligente.Regras`.
  """
  alias Tec0301Pon.PON.Fato

  @doc """
  Inicia a malha PON do Prédio Inteligente: 8 fatos e 7 regras (DSL).
  Ordem das regras: emergência (1, 6, 7), CO2/conforto (2, 5), luz (3, 4).
  """
  def start_link do
    Fato.start_link(:predio_temp_sala, 26)
    Fato.start_link(:predio_ocupacao_sala, false)
    Fato.start_link(:predio_hora_noturna, true)
    Fato.start_link(:predio_alarme_incendio, false)
    Fato.start_link(:predio_porta_aberta, false)
    Fato.start_link(:predio_co2_alto, false)
    Fato.start_link(:predio_luz_sala_ligada, true)
    Fato.start_link(:predio_modo_emergencia, false)

    Tec0301Pon.Examples.PredioInteligente.Regras.RegraEmergencia.start_link()
    Tec0301Pon.Examples.PredioInteligente.Regras.RegraTrancarPorta.start_link()
    Tec0301Pon.Examples.PredioInteligente.Regras.RegraSairEmergencia.start_link()
    Tec0301Pon.Examples.PredioInteligente.Regras.RegraVentilarCO2.start_link()
    Tec0301Pon.Examples.PredioInteligente.Regras.RegraLigarAr.start_link()
    Tec0301Pon.Examples.PredioInteligente.Regras.RegraLuzOff.start_link()
    Tec0301Pon.Examples.PredioInteligente.Regras.RegraLuzOn.start_link()

    {:ok, self()}
  end

  @doc """
  Simula a sequência do plano: noite/sala vazia → apagar luz; ocupação → acender luz;
  temperatura alta → ar; CO2 → ventilar; emergência → modo emergência e trancar; fim → sair da emergência.
  """
  def simular do
    IO.puts("--- Prédio Inteligente: simulação ---")
    Process.sleep(500)

    IO.puts("\n[Sensor] Confirmando: noite, sala vazia, luz ligada.")
    Fato.atualizar(:predio_ocupacao_sala, false)
    Process.sleep(800)

    IO.puts("\n[Sensor] Ocupação: pessoa entrou na sala.")
    Fato.atualizar(:predio_ocupacao_sala, true)
    Process.sleep(800)

    IO.puts("\n[Sensor] Temperatura subiu para 30°C.")
    Fato.atualizar(:predio_temp_sala, 30)
    Process.sleep(800)

    IO.puts("\n[Sensor] CO2 alto detectado.")
    Fato.atualizar(:predio_co2_alto, true)
    Process.sleep(800)

    IO.puts("\n[Sensor] ALARME DE INCÊNDIO ativado.")
    Fato.atualizar(:predio_porta_aberta, true)
    Process.sleep(400)
    Fato.atualizar(:predio_alarme_incendio, true)
    Process.sleep(1200)

    IO.puts("\n[Sensor] Alarme desativado (resposta concluída).")
    Fato.atualizar(:predio_alarme_incendio, false)
    Process.sleep(800)

    IO.puts("\n--- Fim da simulação Prédio Inteligente ---")
  end
end
