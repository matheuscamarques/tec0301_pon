defmodule SimulacoesVisuais.SmartBrewery.NxSim do
  @moduledoc """
  Simulação FBE_03 com Nx: Cholesky + normais correlacionadas (artigo 07 §3.2, §4.1).
  Dado key e matriz de correlação 3×3, retorna [pump_speed, diff_pressure, wort_clarity] e novo key.
  """

  # Ranges para mapear y ~ N(0,1) para variáveis: pump_speed, diff_pressure, wort_clarity
  @ranges [{20, 80}, {40, 200}, {5, 80}]

  @doc """
  Gera três variáveis correlacionadas FBE_03 via Cholesky e Nx.Random.

  - `key` – PRNG key de `Nx.Random.key/1`
  - `correlation` – matriz 3×3 simétrica positiva definida (lista de listas)

  Retorna `{[pump_speed, diff_pressure, wort_clarity], new_key}`.
  Valores são escalados para as faixas [20,80], [40,200], [5,80] e arredondados a 2 decimais.
  """
  def fbe03_correlated(key, correlation) do
    corr_t = Nx.tensor(correlation, type: {:f, 32})
    l = Nx.LinAlg.cholesky(corr_t)
    {z, new_key} = Nx.Random.normal(key, 0.0, 1.0, shape: {3})
    # y = L @ z (vetor coluna); Nx.dot(L, z) com L {3,3} e z {3} => {3}
    y = Nx.dot(l, z)
    vals = map_y_to_ranges(y)
    {vals, new_key}
  end

  defp map_y_to_ranges(y_tensor) do
    y_list = Nx.to_flat_list(y_tensor)

    Enum.zip(y_list, @ranges)
    |> Enum.map(fn {yi, {min_r, max_r}} ->
      # yi ~ N(0,1); mapear para [min_r, max_r] via percentil aproximado (igual ao Monte Carlo)
      x = (yi + 2) / 4
      x = max(0, min(1, x))
      round((min_r + x * (max_r - min_r)) * 100) / 100
    end)
  end
end
