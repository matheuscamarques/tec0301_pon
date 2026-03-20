defmodule SimulacoesVisuais.SmartBrewery.NxSimTest do
  use ExUnit.Case, async: true

  alias SimulacoesVisuais.SmartBrewery.{Fbe03Pure, NxSim}
  alias SimulacoesVisuais.SmartBrewery.Cholesky

  @correlation [
    [1.0, 0.8, -0.5],
    [0.8, 1.0, -0.7],
    [-0.5, -0.7, 1.0]
  ]

  describe "fbe03_correlated/1" do
    test "matches fbe03_correlated/2 with default_correlation/0" do
      st = Fbe03Pure.seed(77)
      {a, s1} = NxSim.fbe03_correlated(st)
      {b, s2} = NxSim.fbe03_correlated(st, NxSim.default_correlation())
      assert a == b
      assert s1 == s2
    end
  end

  describe "fbe03_correlated/2" do
    test "returns a three-element tuple and a new PRNG state" do
      st = Fbe03Pure.seed(42)
      {vals, new_st} = NxSim.fbe03_correlated(st, @correlation)

      assert is_tuple(vals)
      assert tuple_size(vals) == 3
      assert {_, _, _} = vals
      assert new_st != st
    end

    test "values are within FBE_03 ranges and rounded to 2 decimals" do
      st = Fbe03Pure.seed(123)

      {{pump_speed, diff_pressure, wort_clarity}, _new_st} =
        NxSim.fbe03_correlated(st, @correlation)

      assert pump_speed >= 20 and pump_speed <= 80
      assert diff_pressure >= 40 and diff_pressure <= 200
      assert wort_clarity >= 5 and wort_clarity <= 80

      assert pump_speed == Float.round(pump_speed, 2)
      assert diff_pressure == Float.round(diff_pressure, 2)
      assert wort_clarity == Float.round(wort_clarity, 2)
    end

    test "new state is different from input state (PRNG advances)" do
      st = Fbe03Pure.seed(999)
      {_vals, new_st} = NxSim.fbe03_correlated(st, @correlation)
      assert new_st != st
    end

    test "deterministic seed yields deterministic values" do
      st = Fbe03Pure.seed(0)
      {vals_a, _} = NxSim.fbe03_correlated(st, @correlation)
      {vals_b, _} = NxSim.fbe03_correlated(st, @correlation)
      assert vals_a == vals_b
    end
  end

  describe "Cholesky equivalence with legacy Cholesky module" do
    test "Nx Cholesky L matches legacy decompose_3x3 for same matrix" do
      {:ok, l_legacy} = Cholesky.decompose_3x3(@correlation)
      l_nx = Nx.tensor(@correlation, type: {:f, 32}) |> Nx.LinAlg.cholesky()

      l_flat_legacy = List.flatten(l_legacy)
      l_flat_nx = Nx.to_flat_list(l_nx)

      assert length(l_flat_nx) == 9

      Enum.zip(l_flat_legacy, l_flat_nx)
      |> Enum.each(fn {a, b} ->
        assert abs(a - b) < 1.0e-5, "expected #{a}, got #{b}"
      end)
    end

    test "L @ z matches legacy multiply_l_times_z for same L and z" do
      {:ok, l_legacy} = Cholesky.decompose_3x3(@correlation)
      z = [0.5, -0.3, 1.0]
      y_legacy = Cholesky.multiply_l_times_z(l_legacy, z)

      l_nx = Nx.tensor(l_legacy, type: {:f, 32})
      z_nx = Nx.tensor(z, type: {:f, 32})
      y_nx = Nx.dot(l_nx, z_nx) |> Nx.to_flat_list()

      Enum.zip(y_legacy, y_nx)
      |> Enum.each(fn {a, b} ->
        assert abs(a - b) < 1.0e-5, "expected #{a}, got #{b}"
      end)
    end
  end
end
