# Portão eletrônico (PoC). Execute: mix run examples/portao_eletronico_simulacao.exs
Application.ensure_all_started(:tec0301_pon)
Tec0301Pon.Examples.PortaoEletronico.start_link()
Tec0301Pon.Examples.PortaoEletronico.simular()
