defmodule SimulacoesVisuais.ML.Pilots.OeeLinear do
  @moduledoc """
  Regressão linear (Scholar) para prever `oee_pct` a partir de telemetria FBE_08 agregada por minuto.
  """
  alias SimulacoesVisuais.ML.{CsvExport, Features}

  @doc """
  Retorna métricas de teste `{:ok, %{mae: _, r2: _, n_train: _, n_test: _, fact_names: _}}` ou `{:error, reason}`.
  """
  def run(export_dir) when is_binary(export_dir) do
    tel_path = Path.join(export_dir, "telemetry_events.csv")
    oee_path = Path.join(export_dir, "oee_snapshots.csv")

    unless File.exists?(tel_path) and File.exists?(oee_path) do
      {:error, :missing_csv}
    else
      tel = CsvExport.read_telemetry!(tel_path)
      oee = CsvExport.read_oee!(oee_path)

      with {:ok, {x, y, names}} <- Features.oee_supervised_dataset(tel, oee) do
        n = Nx.axis_size(x, 0)

        if n < 6 do
          {:error, :insufficient_data}
        else
          split = max(2, div(n * 8, 10))
          f = Nx.axis_size(x, 1)

          x_train = Nx.slice(x, [0, 0], [split, f])
          y_train = Nx.slice(y, [0], [split])
          x_test = Nx.slice(x, [split, 0], [n - split, f])
          y_test = Nx.slice(y, [split], [n - split])

          model = Scholar.Linear.LinearRegression.fit(x_train, y_train)
          pred = Scholar.Linear.LinearRegression.predict(model, x_test)

          mae = Scholar.Metrics.Regression.mean_absolute_error(y_test, pred)
          r2 = Scholar.Metrics.Regression.r2_score(y_test, pred)

          {:ok,
           %{
             mae: Nx.to_number(mae),
             r2: Nx.to_number(r2),
             n_train: split,
             n_test: n - split,
             fact_names: names
           }}
        end
      end
    end
  end
end
