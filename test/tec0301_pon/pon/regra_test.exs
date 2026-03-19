defmodule Tec0301Pon.PON.RegraTest do
  use ExUnit.Case, async: false
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.PON.Regra

  setup do
    n1 = :"regra_f1_#{System.unique_integer([:positive])}"
    n2 = :"regra_f2_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(n1, 0)
    {:ok, _} = Fato.start_link(n2, 0)
    %{f1: n1, f2: n2}
  end

  test "regra with anonymous functions fires when condition is true", %{f1: f1, f2: f2} do
    hit = :erlang.make_ref()
    test_pid = self()

    {:ok, _} =
      Regra.start_link(
        [f1, f2],
        fn mem -> Map.get(mem, f1) == 1 and Map.get(mem, f2) == 2 end,
        fn _mem -> send(test_pid, hit) end
      )

    Fato.atualizar(f1, 1)
    Process.sleep(20)
    Fato.atualizar(f2, 2)
    assert_receive ^hit, 500
  end

  test "regra with module (avaliar/executar) fires when condition is true" do
    Process.register(self(), :regra_test_receiver)

    on_exit(fn ->
      try do
        Process.unregister(:regra_test_receiver)
      rescue
        _ -> :ok
      end
    end)

    {:ok, pa} = Fato.start_link(:regra_test_a, 0)
    {:ok, pb} = Fato.start_link(:regra_test_b, 0)

    defmodule RegraTestMod do
      def avaliar(mem), do: mem[:regra_test_a] == 1 and mem[:regra_test_b] == 2
      def executar(_mem), do: send(Process.whereis(:regra_test_receiver), :regra_fired)
    end

    {:ok, pr} = Regra.start_link([:regra_test_a, :regra_test_b], RegraTestMod)

    on_exit(fn ->
      Process.exit(pa, :normal)
      Process.exit(pb, :normal)
      Process.exit(pr, :normal)
    end)

    Fato.atualizar(:regra_test_a, 1)
    Process.sleep(20)
    Fato.atualizar(:regra_test_b, 2)
    assert_receive :regra_fired, 500
  end
end
