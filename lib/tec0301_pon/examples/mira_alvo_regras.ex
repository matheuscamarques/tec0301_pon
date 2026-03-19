defmodule Tec0301Pon.Examples.MiraAlvo.Regras do
  @moduledoc """
  Regras da Mira ao Alvo definidas via DSL (PON.Builder).
  """
  use Tec0301Pon.PON.Builder

  defrule(RegraDisparo,
    watch: [:mira_alvo_detectado, :mira_alinhada],
    when: memoria[:mira_alvo_detectado] == true and memoria[:mira_alinhada] == true,
    do: IO.puts("\n[Regra Mira] Alvo na mira: DISPARO autorizado.")
  )
end
