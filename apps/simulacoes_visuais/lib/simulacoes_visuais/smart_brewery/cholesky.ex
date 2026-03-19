defmodule SimulacoesVisuais.SmartBrewery.Cholesky do
  @moduledoc """
  Decomposição de Cholesky para matriz de covariância 3×3 (artigo 07 §3.2).
  Usada para gerar variáveis correlacionadas (ex.: FBE_03 pump_speed, diff_pressure, wort_clarity).
  Dado C = L * L^T, retorna L (triangular inferior); depois z_corr = L * z com z vetor de normais.
  """
  # Matriz 3x3: [[a00,a01,a02],[a10,a11,a12],[a20,a21,a22]]
  # Cholesky L tal que L*L^T = A. L[i,j] = 0 para j > i.
  @doc """
  Decompõe matriz 3×3 simétrica positiva definida em L (triangular inferior).
  Retorna {:ok, l} ou :error se a matriz não for positiva definida.
  """
  def decompose_3x3([[a00, _a01, _a02], [a10, a11, _a12], [a20, a21, a22]]) do
    l00 = :math.sqrt(a00)
    if l00 != l00 or l00 <= 0, do: :error
    l10 = a10 / l00
    l20 = a20 / l00
    l11_sq = a11 - l10 * l10
    if l11_sq < 0, do: :error
    l11 = :math.sqrt(l11_sq)
    l21 = (a21 - l20 * l10) / l11
    l22_sq = a22 - l20 * l20 - l21 * l21
    if l22_sq < 0, do: :error
    l22 = :math.sqrt(l22_sq)
    {:ok, [[l00, 0, 0], [l10, l11, 0], [l20, l21, l22]]}
  end

  @doc """
  Multiplica vetor coluna z (lista de 3 números) pela matriz triangular inferior L (3x3).
  Retorna novo vetor [y0, y1, y2] = L * z.
  """
  def multiply_l_times_z([[l00, _, _], [l10, l11, _], [l20, l21, l22]], [z0, z1, z2]) do
    [
      l00 * z0,
      l10 * z0 + l11 * z1,
      l20 * z0 + l21 * z1 + l22 * z2
    ]
  end
end
