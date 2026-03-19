defmodule Tec0301Pon.Examples.AlarmeSimples.Regras do
  @moduledoc """
  Regras do Alarme Simples definidas via DSL (PON.Builder).
  """
  use Tec0301Pon.PON.Builder
  alias Tec0301Pon.Adapters.AlarmeIO

  defrule(RegraAlarmeMonitorado,
    watch: [:alarme_ligado, :sensor_anomalia],
    when: memoria[:alarme_ligado] == true and memoria[:sensor_anomalia] == true,
    do:
      (
        IO.puts("\n[Regra Alarme] Condição atendida: disparando sirene e notificando usuários.")
        AlarmeIO.disparar("Anomalia detectada com alarme armado!")
      )
  )
end
