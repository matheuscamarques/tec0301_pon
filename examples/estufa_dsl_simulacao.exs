# Simulação da Estufa usando a DSL (defrule).
# Execute com: mix run examples/estufa_dsl_simulacao.exs

Application.ensure_all_started(:tec0301_pon)

Tec0301Pon.Examples.Estufa.start_link()
Tec0301Pon.Examples.Estufa.simular()
