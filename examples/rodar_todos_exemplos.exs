# Roda todos os exemplos PON (provas de conceito) em sequência.
# Execute: mix run examples/rodar_todos_exemplos.exs

Application.ensure_all_started(:tec0301_pon)

exemplos = [
  {"1. Alarme simples (monitorado)", &Tec0301Pon.Examples.AlarmeSimples.start_link/0, &Tec0301Pon.Examples.AlarmeSimples.simular/0},
  {"2. Alarme por correlação de sensores", &Tec0301Pon.Examples.AlarmeCorrelacao.start_link/0, &Tec0301Pon.Examples.AlarmeCorrelacao.simular/0},
  {"3. Sistema de Vendas", &Tec0301Pon.Examples.Vendas.start_link/0, &Tec0301Pon.Examples.Vendas.simular/0},
  {"4. Portão eletrônico", &Tec0301Pon.Examples.PortaoEletronico.start_link/0, &Tec0301Pon.Examples.PortaoEletronico.simular/0},
  {"5. Mira ao Alvo", &Tec0301Pon.Examples.MiraAlvo.start_link/0, &Tec0301Pon.Examples.MiraAlvo.simular/0},
  {"6. Estufa inteligente", &Tec0301Pon.Examples.Estufa.start_link/0, &Tec0301Pon.Examples.Estufa.simular/0},
  {"7. Prédio Inteligente", &Tec0301Pon.Examples.PredioInteligente.start_link/0, &Tec0301Pon.Examples.PredioInteligente.simular/0}
]

IO.puts("========================================")
IO.puts("  PoCs PON — rodando todos os exemplos")
IO.puts("========================================\n")

Enum.each(exemplos, fn {nome, start_fn, sim_fn} ->
  IO.puts("\n>>> #{nome}")
  start_fn.()
  sim_fn.()
  Process.sleep(800)
end)

IO.puts("\n========================================")
IO.puts("  Todos os exemplos concluídos.")
IO.puts("========================================")
