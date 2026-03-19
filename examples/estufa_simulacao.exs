# Script para rodar a simulação da Estufa Inteligente.
# Execute com: mix run examples/estufa_simulacao.exs
#
# O Application inicia o Registry; em seguida iniciamos Fatos e Regras
# e simulamos atualizações de sensores (Inbound).

Application.ensure_all_started(:tec0301_pon)

Tec0301Pon.Examples.Estufa.start_link()
Tec0301Pon.Examples.Estufa.simular()
