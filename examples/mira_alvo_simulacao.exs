# Mira ao Alvo (PoC). Execute: mix run examples/mira_alvo_simulacao.exs
Application.ensure_all_started(:tec0301_pon)
Tec0301Pon.Examples.MiraAlvo.start_link()
Tec0301Pon.Examples.MiraAlvo.simular()
