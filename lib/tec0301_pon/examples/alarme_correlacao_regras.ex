defmodule Tec0301Pon.Examples.AlarmeCorrelacao.Regras do
  @moduledoc """
  Regras do Alarme por Correlação definidas via DSL (PON.Builder).
  """
  use Tec0301Pon.PON.Builder
  alias Tec0301Pon.Adapters.AlarmeIO

  defrule(RegraCorrelacao,
    watch: [:alarme_corr_sensor_temp, :alarme_corr_sensor_presenca, :alarme_corr_sistema_ativo],
    when:
      memoria[:alarme_corr_sensor_temp] == true and memoria[:alarme_corr_sensor_presenca] == true and
        memoria[:alarme_corr_sistema_ativo] == true,
    do:
      (
        IO.puts("\n[Regra Alarme Correlação] Três sensores ativos: ativando alarme por 60s.")
        AlarmeIO.disparar("Correlação: temperatura + presença com sistema ativo!")
      )
  )
end
