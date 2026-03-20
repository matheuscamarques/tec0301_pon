defmodule SimulacoesVisuais.SmartBrewery.Fbe03Pure do
  @moduledoc """
  FBE_03 correlacionadas sem Nx no hot path: factor Cholesky pré-calculado + `:rand` com estado
  explícito (`:rand.uniform_real_s/1`). Mesmo mapeamento que o antigo `NxSim` (percentil aproximado
  e arredondamento a 2 decimais).

  Ver `SimulacoesVisuais.SmartBrewery.NxSim` — facade com o mesmo nome de API pública.
  """
  alias SimulacoesVisuais.SmartBrewery.Cholesky

  @mins {20.0, 40.0, 5.0}
  @maxs {80.0, 200.0, 80.0}

  @default_correlation [
    [1.0, 0.8, -0.5],
    [0.8, 1.0, -0.7],
    [-0.5, -0.7, 1.0]
  ]

  @l_default (fn ->
                {:ok, l} = Cholesky.decompose_3x3(@default_correlation)
                l
              end).()

  @doc "Matriz de correlação 3×3 default (FBE_03)."
  def default_correlation, do: @default_correlation

  @doc """
  Inicializa o estado PRNG (`:rand`) a partir de um inteiro (ex.: `:erlang.phash2/1`).
  """
  def seed(integer) when is_integer(integer) do
    :rand.seed_s(:exsss, integer)
  end

  @doc """
  `state` é o estado opaco devolvido por `seed/1` ou pela chamada anterior a `fbe03_correlated/1`.

  Retorna `{{pump_speed, diff_pressure, wort_clarity}, new_state}`.
  """
  def fbe03_correlated(state) do
    fbe03_correlated_with_l(state, @l_default)
  end

  def fbe03_correlated(state, correlation) when is_list(correlation) do
    if correlation == @default_correlation do
      fbe03_correlated_with_l(state, @l_default)
    else
      {:ok, l} = Cholesky.decompose_3x3(correlation)
      fbe03_correlated_with_l(state, l)
    end
  end

  defp fbe03_correlated_with_l(state, l) do
    {z0, s1} = randn_s(state)
    {z1, s2} = randn_s(s1)
    {z2, s3} = randn_s(s2)
    y = Cholesky.multiply_l_times_z(l, [z0, z1, z2])
    vals = map_y_to_ranges(y)
    {vals, s3}
  end

  defp randn_s(state) do
    {u1, s1} = :rand.uniform_real_s(state)
    {u2, s2} = :rand.uniform_real_s(s1)
    u1 = max(u1, 1.0e-12)
    z = :math.sqrt(-2 * :math.log(u1)) * :math.cos(2 * :math.pi() * u2)
    {z, s2}
  end

  defp map_y_to_ranges([y0, y1, y2]) do
    {min0, min1, min2} = @mins
    {max0, max1, max2} = @maxs

    map_one = fn y, min, max ->
      x = (y + 2.0) / 4.0
      x = min(1.0, max(0.0, x))
      span = max - min
      v = min + x * span
      v = Float.round(v * 100.0) / 100.0
      Float.round(v, 2)
    end

    {map_one.(y0, min0, max0), map_one.(y1, min1, max1), map_one.(y2, min2, max2)}
  end
end
