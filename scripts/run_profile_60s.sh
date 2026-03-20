#!/usr/bin/env bash
# Bateria de profiling com PROFILE_PIPELINE_DURATION_MS=60s (ver docs/performance-dev.md).
# Uso: na raiz do repo: ./scripts/run_profile_60s.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/simulacoes_visuais"
mkdir -p tmp/profile

export LOGGER_LEVEL="${LOGGER_LEVEL:-warning}"
export PROFILE_PIPELINE_DURATION_MS="${PROFILE_PIPELINE_DURATION_MS:-60000}"
# Sem TSDB por defeito: sessões longas enchem disco (WAL/inserts) e derrubam o Postgres (disk_full).
export SIMULACOES_TSDB_ENABLED="${SIMULACOES_TSDB_ENABLED:-false}"
# Ignora PROFILE_PIPELINE_MODE herdada do shell (ex. stress com in_process). Sobrescrever esta bateria:
#   PROFILE_PIPELINE_BATTERY_MODE=in_process ./scripts/run_profile_60s.sh
export PROFILE_PIPELINE_MODE="${PROFILE_PIPELINE_BATTERY_MODE:-via_genserver}"
unset PROFILE_PIPELINE_TICKS || true

STAMP="$(date -Iseconds)"
LOG="tmp/profile/run-log-60s.txt"
echo "=== Bateria 60s iniciada $STAMP PROFILE_PIPELINE_DURATION_MS=$PROFILE_PIPELINE_DURATION_MS TSDB=$SIMULACOES_TSDB_ENABLED mode=$PROFILE_PIPELINE_MODE ===" | tee "$LOG"

run() {
  local name="$1"
  shift
  echo "" | tee -a "$LOG"
  echo "=== $(date -Iseconds) $name ===" | tee -a "$LOG"
  "$@" 2>&1 | tee "tmp/profile/${name}-60s.txt"
}

run "cprof" mix profile.cprof -e "SimulacoesVisuais.Profile.PipelineWorkload.run()"
run "cprof-monte-carlo" mix profile.cprof --module SimulacoesVisuais.SmartBreweryMonteCarlo -e "SimulacoesVisuais.Profile.PipelineWorkload.run()"

run "fprof" env PROFILE_PIPELINE_MODE=in_process mix profile.fprof -e "SimulacoesVisuais.Profile.PipelineWorkload.run()"

run "eprof" mix profile.eprof -e "SimulacoesVisuais.Profile.PipelineWorkload.run()"

run "tprof-time" mix profile.tprof --type time --report total -e "SimulacoesVisuais.Profile.PipelineWorkload.run()"
run "tprof-memory" mix profile.tprof --type memory --report total -e "SimulacoesVisuais.Profile.PipelineWorkload.run()"
run "tprof-calls" mix profile.tprof --type calls --report total -e "SimulacoesVisuais.Profile.PipelineWorkload.run()"

echo "" | tee -a "$LOG"
echo "=== Bateria 60s concluída $(date -Iseconds) ===" | tee -a "$LOG"
