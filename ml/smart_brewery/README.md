# Laboratório ML — Smart Brewery (artigos 15 e 16)

## Caminho principal: Elixir (Nx / Axon / Scholar)

O treino recomendado no repositório usa **CSV** de `mix export.ml` e módulos em `apps/simulacoes_visuais/lib/simulacoes_visuais/ml/`:

```bash
cd apps/simulacoes_visuais
mix export.ml --out /tmp/ml_export --since-hours 168
mix train.ml --dir /tmp/ml_export --pilot oee
# ou: --pilot fermentation | anomaly
```

Ver [docs/ml-smart-brewery-data.md](../../docs/ml-smart-brewery-data.md) (secção “Treino em Elixir”).

**Nota:** Scholar não implementa Random Forest / XGBoost (por desenho). Para esses algoritmos, use [EXGBoost](https://hex.pm/packages/exxgboost) ou os scripts Python abaixo como alternativa.

Documentação de dados e mapa artigo 16: [docs/ml-smart-brewery-data.md](../../docs/ml-smart-brewery-data.md).

---

## Scripts Python (opcional)

Úteis para Parquet, PM4Py (process mining), Gymnasium/PPO ou protótipos rápidos em ecossistema Python.

1. Gerar CSVs (como acima).
2. Ambiente virtual e dependências:

   ```bash
   cd ml/smart_brewery
   python -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   # opcional (Chronos, SHAP, Giotto-TDA, …):
   pip install -r requirements-optional.txt
   ```

| Script | Descrição |
|--------|-----------|
| `validation.py` | Walk-forward e splits temporais (reutilizado pelos pilotos). |
| `ingest.py` | Resumo dos CSVs (pandas). |
| `csv_to_parquet.py` | CSV → Parquet (Polars). |
| `pilot_oee_rf.py` | Random Forest (sklearn), split 80/20. |
| `pilot_oee_xgb.py` | **Art. 16** — XGBoost + walk-forward, métricas JSON. |
| `pilot_oee_tda_sarimax.py` | **Art. 16** — exógenas rolantes + SARIMAX. |
| `pilot_tsfm_forecast.py` | **Art. 16** — ICFT por vizinhos; Chronos opcional. |
| `pilot_anomaly_weak_supervision.py` | **Art. 16** — pseudo-rótulos + destilação RF→logit. |
| `pilot_next_rule_baseline.py` | **Art. 16** — Markov ordem 1 para próxima regra. |
| `pilot_anomaly_iforest.py` | Isolation Forest FBE_01. |
| `pilot_fermentation_lstm.py` | LSTM PyTorch. |
| `process_mining_pm4py.py` | PM4Py + `rule_events.csv`; `--xes-out` gera XES. |
| `gym_smart_grid_env.py` | Ambiente Gymnasium FBE_11. |
| `drl_ppo_baseline.py` | Smoke PPO (Stable-Baselines3). |

## Importar predições para o Phoenix

```bash
cd apps/simulacoes_visuais
mix import.ml.predictions --file /tmp/preds.jsonl
```

Depois: `/smart-brewery/ml-predictions`. Detalhes de TSDB, `:tsdb_enabled` e schema: [docs/artigos/26_predicoes_ml_ml_predictions_tsdb.md](../../docs/artigos/26_predicoes_ml_ml_predictions_tsdb.md).

## Segurança (DRL / Smart Grid)

Ver [docs/drl-smart-grid-safety.md](../../docs/drl-smart-grid-safety.md).
