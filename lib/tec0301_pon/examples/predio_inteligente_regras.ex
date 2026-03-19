defmodule Tec0301Pon.Examples.PredioInteligente.Regras do
  @moduledoc """
  Regras do Prédio Inteligente definidas via DSL (PON.Builder).
  Ordem de start: emergência (1, 6, 7), depois CO2/conforto (2, 5), depois luz (3, 4).
  """
  use Tec0301Pon.PON.Builder
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.Adapters.AlarmeIO
  alias Tec0301Pon.Adapters.PredioIO

  defrule(RegraEmergencia,
    watch: [:predio_alarme_incendio],
    when: (memoria[:predio_alarme_incendio] || false) == true,
    do:
      (
        IO.puts("\n⚙️ [Regra 1] EMERGÊNCIA: alarme de incêndio ativo.")
        AlarmeIO.disparar("Alarme de incêndio — modo emergência ativado.")
        Fato.atualizar(:predio_modo_emergencia, true)
      )
  )

  defrule(RegraTrancarPorta,
    watch: [:predio_modo_emergencia, :predio_porta_aberta],
    when:
      (memoria[:predio_modo_emergencia] || false) == true and
        (memoria[:predio_porta_aberta] || false) == true,
    do:
      (
        IO.puts("\n⚙️ [Regra 6] Segurança: trancando porta em modo emergência.")
        PredioIO.trancar_porta()
      )
  )

  defrule(RegraSairEmergencia,
    watch: [:predio_alarme_incendio],
    when: (memoria[:predio_alarme_incendio] || true) == false,
    do:
      (
        IO.puts("\n⚙️ [Regra 7] Alarme desativado: saindo do modo emergência.")
        Fato.atualizar(:predio_modo_emergencia, false)
      )
  )

  defrule(RegraVentilarCO2,
    watch: [:predio_co2_alto, :predio_modo_emergencia],
    when:
      (memoria[:predio_co2_alto] || false) == true and
        (memoria[:predio_modo_emergencia] || true) == false,
    do:
      (
        IO.puts("\n⚙️ [Regra 2] CO2 alto: acionando ventilação.")
        PredioIO.ventilar()
      )
  )

  defrule(RegraLigarAr,
    watch: [:predio_temp_sala, :predio_ocupacao_sala, :predio_modo_emergencia],
    when:
      (memoria[:predio_temp_sala] || 0) > 28 and (memoria[:predio_ocupacao_sala] || false) == true and
        (memoria[:predio_modo_emergencia] || true) == false,
    do:
      (
        IO.puts("\n⚙️ [Regra 5] Conforto: temperatura alta com ocupação — ligando ar.")
        PredioIO.ligar_ar()
      )
  )

  defrule(RegraLuzOff,
    watch: [:predio_ocupacao_sala, :predio_hora_noturna, :predio_luz_sala_ligada],
    when:
      (memoria[:predio_ocupacao_sala] || true) == false and
        (memoria[:predio_hora_noturna] || false) == true and
        (memoria[:predio_luz_sala_ligada] || false) == true,
    do:
      (
        IO.puts("\n⚙️ [Regra 3] Economia: sala vazia à noite — desligando luz.")
        PredioIO.desligar_luz()
        Fato.atualizar(:predio_luz_sala_ligada, false)
      )
  )

  defrule(RegraLuzOn,
    watch: [:predio_ocupacao_sala, :predio_hora_noturna, :predio_luz_sala_ligada],
    when:
      (memoria[:predio_ocupacao_sala] || false) == true and
        (memoria[:predio_hora_noturna] || false) == true and
        (memoria[:predio_luz_sala_ligada] || true) == false,
    do:
      (
        IO.puts("\n⚙️ [Regra 4] Conforto: ocupação à noite — ligando luz.")
        PredioIO.ligar_luz()
        Fato.atualizar(:predio_luz_sala_ligada, true)
      )
  )
end
