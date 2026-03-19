defmodule SimulacoesVisuais.SmartBrewery.NoiseTest do
  use ExUnit.Case, async: true

  alias SimulacoesVisuais.SmartBrewery.Noise

  @n 10_000

  describe "box_muller/0" do
    test "produces two values" do
      {z1, z2} = Noise.box_muller()
      assert is_float(z1) and is_float(z2)
    end

    test "large sample has mean near 0 and std near 1" do
      samples =
        Enum.flat_map(1..div(@n, 2), fn _ ->
          {z1, z2} = Noise.box_muller()
          [z1, z2]
        end)

      mean = Enum.sum(samples) / length(samples)

      variance =
        Enum.reduce(samples, 0, fn x, acc -> acc + (x - mean) * (x - mean) end) / length(samples)

      sigma = :math.sqrt(variance)

      assert abs(mean) < 0.1
      assert sigma >= 0.9 and sigma <= 1.1
    end
  end

  describe "normal/2" do
    test "scales to mean and sigma" do
      mu = 50.0
      sigma = 5.0
      samples = Enum.map(1..@n, fn _ -> Noise.normal(mu, sigma) end)
      mean = Enum.sum(samples) / length(samples)

      variance =
        Enum.reduce(samples, 0, fn x, acc -> acc + (x - mean) * (x - mean) end) / length(samples)

      sample_sigma = :math.sqrt(variance)

      assert abs(mean - mu) < 0.2
      assert abs(sample_sigma - sigma) < 0.2
    end
  end
end
