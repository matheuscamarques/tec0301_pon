defmodule Tec0301Pon.Examples.PortaoEletronico.Regras do
  @moduledoc """
  Regras do Portão Eletrônico definidas via DSL (PON.Builder).
  """
  use Tec0301Pon.PON.Builder
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.Adapters.PortaoIO

  defrule(RegraAbrirPortao,
    watch: [:portao_comando_abrir, :portao_sensor_obstaculo, :portao_aberto],
    when:
      memoria[:portao_comando_abrir] == true and memoria[:portao_sensor_obstaculo] == false and
        memoria[:portao_aberto] == false,
    do:
      (
        IO.puts("\n[Regra Portão] Comando de abertura sem obstáculo: acionando motor.")
        PortaoIO.abrir()
        Fato.atualizar(:portao_aberto, true)
      )
  )
end
