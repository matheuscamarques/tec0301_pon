#!/usr/bin/env bash
# Inicia a Smart Brewery com TSDB + Monte Carlo automático (sem depender do frontend).
# Uso (na raiz do repositório): ./scripts/run_simulation_headless_ml.sh
# Variáveis opcionais: SIMULACOES_TSDB_ENABLED, AUTO_START_MONTE_CARLO, MONTE_CARLO_INTERVAL_MS, LOGGER_LEVEL, PORT
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/simulacoes_visuais"

export SIMULACOES_TSDB_ENABLED="${SIMULACOES_TSDB_ENABLED:-true}"
export AUTO_START_MONTE_CARLO="${AUTO_START_MONTE_CARLO:-true}"

exec mix phx.server "$@"
