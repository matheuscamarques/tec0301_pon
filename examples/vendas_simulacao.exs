# Sistema de Vendas simplificado (PoC). Execute: mix run examples/vendas_simulacao.exs
Application.ensure_all_started(:tec0301_pon)
Tec0301Pon.Examples.Vendas.start_link()
Tec0301Pon.Examples.Vendas.simular()
