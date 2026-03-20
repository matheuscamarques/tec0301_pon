defmodule SimulacoesVisuais.ML.Pilots.AnomalyAutoencoder do
  @moduledoc """
  Autoencoder pequeno (Axon) em fatos FBE_01 (moinho): reconstrução MSE como score de anomalia.
  """
  alias SimulacoesVisuais.ML.{CsvExport, Features}

  @doc """
  Treina com entrada = alvo (reconstrução). Retorna `{:ok, %{mean_train_mse: float, max_train_mse: float}}`.
  """
  def run(export_dir, opts \\ []) when is_binary(export_dir) do
    tel_path = Path.join(export_dir, "telemetry_events.csv")
    epochs = Keyword.get(opts, :epochs, 40)
    log = Keyword.get(opts, :log, 0)

    unless File.exists?(tel_path) do
      {:error, :missing_csv}
    else
      tel = CsvExport.read_telemetry!(tel_path)

      with {:ok, {x, fact_names}} <- Features.mill_matrix(tel) do
        n = Nx.axis_size(x, 0)
        nf = Nx.axis_size(x, 1)

        if n < 8 or nf < 2 do
          {:error, :insufficient_data}
        else
          split = max(4, div(n * 85, 100))
          x_train = Nx.slice(x, [0, 0], [split, nf])

          latent = max(2, div(nf, 2))

          model =
            Axon.input("x", shape: {nil, nf})
            |> Axon.dense(latent, activation: :relu)
            |> Axon.dense(nf, activation: :linear)

          data = ae_batch_stream(x_train, 16)

          final_model_state =
            model
            |> Axon.Loop.trainer(:mean_squared_error, :adam, log: log)
            |> Axon.Loop.run(data, %{}, epochs: epochs)

          pred = Axon.predict(model, final_model_state, x_train)
          err = Nx.pow(Nx.subtract(x_train, pred), 2) |> Nx.mean(axes: [1])

          {:ok,
           %{
             mean_train_mse: err |> Nx.mean() |> Nx.to_number(),
             max_train_mse: err |> Nx.reduce_max() |> Nx.to_number(),
             n_features: nf,
             fact_names: fact_names
           }}
        end
      end
    end
  end

  defp ae_batch_stream(x, batch_size) do
    n = Nx.axis_size(x, 0)
    f = Nx.axis_size(x, 1)

    Stream.unfold(0, fn start ->
      if start >= n do
        nil
      else
        len = min(batch_size, n - start)
        bx = Nx.slice(x, [start, 0], [len, f])
        {{bx, bx}, start + len}
      end
    end)
  end
end
