# Script para rodar a simulação do Gêmeo Digital Smart Brewery (Artigo 05).
# Execute com: mix run examples/smart_brewery_simulacao.exs
#
# Inicia 57 fatos e 3 regras PON; simula o efeito cascata da sec. 6.1 (R_01)
# e opcionalmente R_02 e R_03.

Application.ensure_all_started(:tec0301_pon)

Tec0301Pon.Examples.SmartBrewery.start_link()
Tec0301Pon.Examples.SmartBrewery.simular()
