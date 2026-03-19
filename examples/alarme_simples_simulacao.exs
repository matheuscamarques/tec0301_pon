# Alarme monitorado — exemplo extraído dos recursos (Ronszcka 2019, Wiecheteck 2011).
# Execute: mix run examples/alarme_simples_simulacao.exs

Application.ensure_all_started(:tec0301_pon)

Tec0301Pon.Examples.AlarmeSimples.start_link()
Tec0301Pon.Examples.AlarmeSimples.simular()
