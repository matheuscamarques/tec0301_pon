# Alarme por correlação de sensores (PoC). Execute: mix run examples/alarme_correlacao_simulacao.exs
Application.ensure_all_started(:tec0301_pon)
Tec0301Pon.Examples.AlarmeCorrelacao.start_link()
Tec0301Pon.Examples.AlarmeCorrelacao.simular()
