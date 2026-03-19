# Script para rodar a simulação do Prédio Inteligente.
# Execute com: mix run examples/predio_inteligente_simulacao.exs
#
# O Application inicia o Registry; em seguida iniciamos Fatos e Regras
# e simulamos a sequência: luz (noite/vazio → ocupação), ar, CO2, emergência, fim.

Application.ensure_all_started(:tec0301_pon)

Tec0301Pon.Examples.PredioInteligente.start_link()
Tec0301Pon.Examples.PredioInteligente.simular()
