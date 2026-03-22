# Laboratório ML — Smart Brewery (artigos 15 e 16)

## Roteiro rápido (Docker → simulação → export → treino)

Execute `mix dev.tsdb`, `mix export.ml` e `mix train.ml` a partir de **`apps/simulacoes_visuais`** (a raiz do monorepo é outro projeto Mix e não expõe estes aliases).

1. **Postgres/TimescaleDB:** na raiz do repositório, `docker compose up -d`.
2. **Migrações:** `cd apps/simulacoes_visuais && mix deps.get && mix ecto.migrate` — obrigatório antes do primeiro export após atualizar o código (o esquema TSDB evolui).
3. **Gerar dados:** `mix dev.tsdb` ou `iex -S mix dev.tsdb`; ou na raiz `./scripts/run_simulation_headless_ml.sh`. Deixe correr tempo suficiente se for usar `--since-hours 168` no export. Para acelerar ticks em dev: `MONTE_CARLO_INTERVAL_MS=500` (mínimo ~200 ms; ver `config/dev.exs`).
4. **Exportar CSVs:** `mix export.ml --out /tmp/ml_export --since-hours 168`. Flags úteis: `--no-cagg` (omitir CAGGs de telemetria), `--no-cagg-1h-1day` (manter 1 min, omitir 1 h e 1 dia).
5. **Treinar:** ver comandos na secção seguinte.

**Objetivos típicos de ML × fontes no TSDB:** séries / forecast → `telemetry_events` e CAGGs (`telemetry_events_1min` / `_1h` / `_1day`, só linhas com `value_float`); KPI OEE → `oee_snapshots`; anomalias → `anomaly_events` (+ telemetria); sequência de regras / process mining → `rule_events`; metadados → `dim_equipamento_fbe`, `dim_variaveis_mapeamento`. Retenção bruta da hypertable é limitada (p.ex. 7 dias por omissão); para janelas longas, export periódico ou `mix retention.tsdb --days N` em `apps/simulacoes_visuais`.

**Art. 16 (resumo):** pilotos avançados cobrem TSFM/ICFT, XGBoost OEE walk-forward, SARIMAX com exógenas, supervisão fraca em anomalias, Markov para próxima regra PON, PM4Py com export XES — alinhados aos scripts da tabela abaixo.

## Caminho principal: Elixir (Nx / Axon / Scholar)

O treino recomendado no repositório usa **CSV** de `mix export.ml` e módulos em `apps/simulacoes_visuais/lib/simulacoes_visuais/ml/`:

```bash
cd apps/simulacoes_visuais
mix export.ml --out /tmp/ml_export --since-hours 168
mix train.ml --dir /tmp/ml_export --pilot oee
# ou: --pilot fermentation | anomaly
```

| Piloto | Ideia | Módulo / biblioteca |
|--------|--------|----------------------|
| `oee` | Regressão linear: OEE vs features alinhadas à telemetria FBE_08 | `SimulacoesVisuais.ML.Pilots.OeeLinear` — Scholar |
| `fermentation` | MLP (Axon) em janela achatada para séries `fbe_06_*` | `SimulacoesVisuais.ML.Pilots.FermentationMlp` |
| `anomaly` | Autoencoder em FBE_01 (moinho), erro de reconstrução | `SimulacoesVisuais.ML.Pilots.AnomalyAutoencoder` |

**Troubleshooting:** o piloto `oee` exige **interseção temporal** entre amostras FBE_08 e `oee_snapshots` no mesmo minuto; com pouca simulação ou janela de export curta pode falhar com dados insuficientes — alargue o tempo de corrida ou `--since-hours`.

**Nota:** Scholar não implementa Random Forest / XGBoost (por desenho). Para esses algoritmos, use [EXGBoost](https://hex.pm/packages/exxgboost) ou os scripts Python abaixo como alternativa.

Valores booleanos/categóricos em `telemetry_events` usam `value_str` / `value_int`; entram no CSV bruto mas **não** nas CAGGs que filtram `value_float IS NOT NULL`. Validação temporal em Python: `ml/smart_brewery/validation.py` (walk-forward).

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

Depois abra **`/smart-brewery/ml-predictions`** na app.

**Persistência:** a tabela **`ml_predictions`** está na mesma instância PostgreSQL que a app (`DATABASE_URL` em dev). Na migration atual é tabela relacional Ecto com índices em `ts` e `(model_name, ts)` — **não** é hypertable Timescale; o objetivo é co-localizar predições com o resto do analytics.

**Configuração:** o `Repo` e writers de telemetria dependem de `config :simulacoes_visuais, :tsdb_enabled`. Em dev o default costuma ser ativo; `SIMULACOES_TSDB_ENABLED=false` desliga. O alias **`mix dev.tsdb`** define `SIMULACOES_TSDB_ENABLED=true` se a variável ainda não existir. Em **`MIX_ENV=test`** o import costuma recusar sem Repo/TSDB — use `MIX_ENV=dev` (ou produção com TSDB) para importar. Sem Repo ativo, a LiveView de predições mostra o aviso correspondente.

**Campos principais:** `model_name` (obrigatório na importação), `ts` (opcional, ISO8601; senão usa o instante atual), `target_name`, `value_float`, `metadata` (JSON), mais `id` (UUID) e timestamps Ecto.

Exemplo mínimo por linha (JSONL):

```json
{"model_name":"pilot_oee_xgb","target_name":"oee","value_float":0.87}
```

Task explícita: `mix simulacoes_visuais.ml_import_predictions --file …`. Opcional: `mix verify.tsdb` para validar conectividade.

## Segurança (DRL / Smart Grid)

1. **Não acoplar** o agente treinado diretamente ao motor PON em produção sem validação, simulação e processo de mudança (MOC).
2. **Modo sugestão:** num primeiro estágio a política deve apenas **recomendar** ou exibir trajetórias, sem gravar fatos na malha reativa.
3. **Guardrails físicos:** limites de temperatura, pressão (NR-13), intertravamentos e proteção de ativos permanecem **restrições duras** — o DRL não as substitui.
4. **Treino offline** com dados históricos e ambientes simulados; **`gym_smart_grid_env.py`** é **didático**, não calibrado a planta real.

O DRL é ferramenta de pesquisa e otimização; segurança de pessoas e equipamentos continua governada por normas, interlocks e regras PON auditáveis.
