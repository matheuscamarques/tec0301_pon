defmodule SimulacoesVisuais.ML.Pilots.FermentationMlp do
  @moduledoc """
  MLP (Axon) sobre janela achatada de `fbe_06_*` para prever o próximo passo (multivariado).
  """
  alias SimulacoesVisuais.ML.{CsvExport, Features}

  @doc """
  Treina com `Axon.Loop.trainer/3` (MSE) e retorna `{:ok, %{final_loss: float, n_test: int}}` ou erro.
  """
  def run(export_dir, opts \\ []) when is_binary(export_dir) do
    tel_path = Path.join(export_dir, "telemetry_events.csv")
    epochs = Keyword.get(opts, :epochs, 50)
    log = Keyword.get(opts, :log, 0)

    unless File.exists?(tel_path) do
      {:error, :missing_csv}
    else
      tel = CsvExport.read_telemetry!(tel_path)

      with {:ok, {x, y, flat_len, n_feat}} <- Features.fermentation_windows(tel, opts) do
        n = Nx.axis_size(x, 0)

        if n < 4 do
          {:error, :insufficient_data}
        else
          split = max(2, div(n * 85, 100))
          x_train = Nx.slice(x, [0, 0], [split, flat_len])
          y_train = Nx.slice(y, [0, 0], [split, n_feat])
          x_test = Nx.slice(x, [split, 0], [n - split, flat_len])
          y_test = Nx.slice(y, [split, 0], [n - split, n_feat])

          model =
            Axon.input("x", shape: {nil, flat_len})
            |> Axon.dense(32, activation: :relu)
            |> Axon.dense(n_feat, activation: :linear)

          data = batch_stream(x_train, y_train, 16)

          final_model_state =
            model
            |> Axon.Loop.trainer(:mean_squared_error, :adam, log: log)
            |> Axon.Loop.run(data, %{}, epochs: epochs)

          pred = Axon.predict(model, final_model_state, x_test)

          test_loss =
            Scholar.Metrics.Regression.mean_square_error(y_test, pred)

          {:ok,
           %{
             final_loss: Nx.to_number(test_loss),
             n_train: split,
             n_test: n - split,
             n_feat: n_feat
           }}
        end
      end
    end
  end

  defp batch_stream(x, y, batch_size) do
    n = Nx.axis_size(x, 0)
    f = Nx.axis_size(x, 1)
    nf = Nx.axis_size(y, 1)

    Stream.unfold(0, fn start ->
      if start >= n do
        nil
      else
        len = min(batch_size, n - start)
        bx = Nx.slice(x, [start, 0], [len, f])
        by = Nx.slice(y, [start, 0], [len, nf])
        {{bx, by}, start + len}
      end
    end)
  end
end
