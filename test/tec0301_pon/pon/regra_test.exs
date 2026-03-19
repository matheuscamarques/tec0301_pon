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

  test "regra does not fire when condition stays false", %{f1: f1, f2: f2} do
    test_pid = self()
    {:ok, _} =
      Regra.start_link(
        [f1, f2],
        fn mem -> Map.get(mem, f1) == 1 and Map.get(mem, f2) == 2 end,
        fn _mem -> send(test_pid, :fired) end
      )
    Fato.atualizar(f1, 0)
    Process.sleep(20)
    Fato.atualizar(f2, 0)
    Process.sleep(50)
    refute_receive :fired, 100
  end

  test "regra with single fact fires when condition becomes true", %{f1: f1} do
    hit = :erlang.make_ref()
    test_pid = self()
    {:ok, _} =
      Regra.start_link(
        [f1],
        fn mem -> Map.get(mem, f1) == 7 end,
        fn _mem -> send(test_pid, hit) end
      )
    Fato.atualizar(f1, 7)
    assert_receive ^hit, 500
  end

  test "regra with module has memory filled from facts at init" do
    Process.register(self(), :regra_mem_receiver)
    on_exit(fn -> try do Process.unregister(:regra_mem_receiver) rescue _ -> :ok end end)
    {:ok, _} = Fato.start_link(:regra_mem_a, 10)
    {:ok, _} = Fato.start_link(:regra_mem_b, 20)
    defmodule RegraMemMod do
      def avaliar(mem), do: mem[:regra_mem_a] == 10 and mem[:regra_mem_b] == 20
      def executar(mem), do: send(Process.whereis(:regra_mem_receiver), {:exec, mem[:regra_mem_a], mem[:regra_mem_b]})
    end
    {:ok, _} = Regra.start_link([:regra_mem_a, :regra_mem_b], RegraMemMod)
    Fato.atualizar(:regra_mem_a, 10)
    assert_receive {:exec, 10, 20}, 500
  end

  test "regra with instigation_list runs task when condition fires" do
    Process.register(self(), :regra_inst_receiver)
    on_exit(fn -> try do Process.unregister(:regra_inst_receiver) rescue _ -> :ok end end)
    {:ok, _} = Fato.start_link(:regra_inst_f1, 0)
    defmodule InstigationTarget do
      def notify do
        send(Process.whereis(:regra_inst_receiver), :instigation_ran)
      end
    end
    defmodule RegraInstMod do
      def avaliar(mem), do: mem[:regra_inst_f1] == 1
      def executar(_mem), do: :ok
    end
    {:ok, _} =
      Regra.start_link(
        [:regra_inst_f1],
        RegraInstMod,
        instigation_list: [{InstigationTarget, :notify, []}]
      )
    Fato.atualizar(:regra_inst_f1, 1)
    assert_receive :instigation_ran, 500
  end

  test "regra estatisticas and reset_estatisticas" do
    f1 = :"regra_stat_f1_#{System.unique_integer([:positive])}"
    f2 = :"regra_stat_f2_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(f1, 0)
    {:ok, _} = Fato.start_link(f2, 0)
    hit = :erlang.make_ref()
    test_pid = self()
    {:ok, regra_pid} =
      Regra.start_link(
        [f1, f2],
        fn mem -> Map.get(mem, f1) == 1 and Map.get(mem, f2) == 2 end,
        fn _mem -> send(test_pid, hit) end
      )
    Fato.atualizar(f1, 0)
    Fato.atualizar(f2, 0)
    Fato.atualizar(f1, 1)
    Fato.atualizar(f2, 2)
    assert_receive ^hit, 500
    s = Regra.estatisticas(regra_pid)
    assert s.notificacoes >= 4
    assert s.execucoes >= 1
    Regra.reset_estatisticas(regra_pid)
    Process.sleep(10)
    s2 = Regra.estatisticas(regra_pid)
    assert s2.notificacoes == 0
    assert s2.execucoes == 0
  end

  test "regra fires once after second fact update when condition needs both", %{f1: f1, f2: f2} do
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
    refute_receive ^hit, 50
    Fato.atualizar(f2, 2)
    assert_receive ^hit, 500
    refute_receive ^hit, 100
  end
end
