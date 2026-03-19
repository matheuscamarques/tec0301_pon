defmodule Tec0301Pon.Examples.Estufa do
  @moduledoc """
  Cenário Estufa Inteligente: Fatos Base, Fato Inferido (estado_bomba) e três regras
  (irrigação, parada, segurança). Rede de inferência em cascata com Adapters hexagonais.

  Regras definidas via DSL em `Estufa.Regras`.
  """
  alias Tec0301Pon.PON.Fato

  @doc """
  Inicia a malha PON da Estufa: Fatos e Regras (DSL). O Registry deve já estar rodando.
  """
  def start_link do
    Fato.start_link(:temp_ambiente, 25)
    Fato.start_link(:umidade_solo, 60)
    Fato.start_link(:nivel_tanque, 100)
    Fato.start_link(:estado_bomba, :desligada)

    Tec0301Pon.Examples.Estufa.Regras.RegraIrrigacao.start_link()
    Tec0301Pon.Examples.Estufa.Regras.RegraParada.start_link()
    Tec0301Pon.Examples.Estufa.Regras.RegraSeguranca.start_link()

    {:ok, self()}
  end

  @doc """
  Simula a sequência do artigo: temperatura sobe, umidade cai, nível do tanque despenca.
  """
  def simular do
    IO.puts("--- INICIANDO SIMULAÇÃO ---")
    Process.sleep(1000)

    IO.puts("\n[Sensor] Temperatura subiu para 32°C.")
    Fato.atualizar(:temp_ambiente, 32)
    Process.sleep(1000)

    IO.puts("[Sensor] Umidade caiu para 35%.")
    Fato.atualizar(:umidade_solo, 35)
    Process.sleep(1000)

    IO.puts("\n[Sensor] Vazamento detectado! Nível do tanque despenca para 5%.")
    Fato.atualizar(:nivel_tanque, 5)
    Process.sleep(2000)
  end
end
