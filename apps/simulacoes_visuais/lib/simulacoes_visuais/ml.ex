defmodule SimulacoesVisuais.ML do
  @moduledoc """
  Machine learning no gêmeo digital Smart Brewery: **artigo 15** (pilotos Nx/Axon/Scholar)
  e **artigo 16** (pipelines avançados em Python sobre o mesmo CSV exportado).

  - **Dados:** `SimulacoesVisuais.ML.CsvExport`, `SimulacoesVisuais.ML.Features`
  - **Modelos (Elixir):** `SimulacoesVisuais.ML.Pilots.*` — regressão linear OEE, MLP fermentação, autoencoder FBE_01
  - **CLI:** `mix train.ml --dir DIR --pilot oee|fermentation|anomaly`
  - **Artigo 16 (offline):** `ml/smart_brewery/` — XGBoost OEE walk-forward, ICFT/Chronos, SARIMAX+exógenas, supervisão fraca, baseline Markov para regras, PM4Py+XES; ver `docs/ml-smart-brewery-data.md`
  """
end
