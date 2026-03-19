defmodule Tec0301Pon.Examples.Estufa.Regras do
  @moduledoc """
  Regras da Estufa definidas via DSL (PON.Builder).
  Inicie os Fatos antes e depois chame start_link/0 em cada submódulo gerado.
  """
  use Tec0301Pon.PON.Builder
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.Adapters.BombaDeAgua
  alias Tec0301Pon.Adapters.AlarmeIO

  defrule(RegraIrrigacao,
    watch: [:temp_ambiente, :umidade_solo, :estado_bomba, :nivel_tanque],
    when:
      memoria[:temp_ambiente] > 30 and memoria[:umidade_solo] < 40 and
        memoria[:estado_bomba] == :desligada and memoria[:nivel_tanque] >= 10,
    do:
      (
        IO.puts("\n⚙️ [Regra 1] Clima seco detectado. Iniciando irrigação...")
        BombaDeAgua.ligar()
        Fato.atualizar(:estado_bomba, :ligada)
      )
  )

  defrule(RegraParada,
    watch: [:umidade_solo, :estado_bomba],
    when: memoria[:umidade_solo] >= 60 and memoria[:estado_bomba] == :ligada,
    do:
      (
        IO.puts("\n⚙️ [Regra 2] Solo umedecido. Parando irrigação...")
        BombaDeAgua.desligar()
        Fato.atualizar(:estado_bomba, :desligada)
      )
  )

  defrule(RegraSeguranca,
    watch: [:nivel_tanque, :estado_bomba],
    when: memoria[:nivel_tanque] < 10 and memoria[:estado_bomba] == :ligada,
    do:
      (
        IO.puts("\n⚙️ [Regra 3] PERIGO: Tentativa de bombear a seco!")
        BombaDeAgua.desligar()
        AlarmeIO.disparar("Nível do tanque crítico com bomba ativa!")
        Fato.atualizar(:estado_bomba, :desligada)
      )
  )
end
