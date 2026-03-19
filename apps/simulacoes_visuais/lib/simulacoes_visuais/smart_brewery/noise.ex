defmodule SimulacoesVisuais.SmartBrewery.Noise do
  @moduledoc """
  Geração de ruído Gaussiano via transformada de Box-Muller (artigo 07 §3.1).
  Usado no Monte Carlo para variáveis contínuas com random walk em vez de
  `Enum.random(min..max)`.
  """
  @pi 3.141592653589793

  @doc """
  Retorna um par `{z1, z2}` de variáveis aleatórias independentes
  com distribuição normal padrão (média 0, desvio 1), a partir
  de duas uniformes em (0, 1] via Box-Muller.
  """
  def box_muller do
    u1 = :rand.uniform()
    u2 = :rand.uniform()
    # Evitar log(0)
    u1_safe = max(u1, 1.0e-10)
    r = :math.sqrt(-2.0 * :math.log(u1_safe))
    theta = 2.0 * @pi * u2
    z1 = r * :math.cos(theta)
    z2 = r * :math.sin(theta)
    {z1, z2}
  end

  @doc """
  Retorna uma amostra normal com média `mu` e desvio padrão `sigma`.
  Usa Box-Muller internamente (apenas uma das duas amostras por chamada).
  """
  def normal(mu, sigma) when is_number(mu) and is_number(sigma) and sigma >= 0 do
    {z1, _z2} = box_muller()
    mu + sigma * z1
  end

  @doc """
  Retorna duas amostras normais independentes com média `mu` e desvio `sigma`.
  """
  def normal_pair(mu, sigma) when is_number(mu) and is_number(sigma) and sigma >= 0 do
    {z1, z2} = box_muller()
    {mu + sigma * z1, mu + sigma * z2}
  end
end
