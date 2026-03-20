defmodule Tec0301Pon.PON.RegraTest do
  use Tec0301Pon.PonCase
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

    on_exit(fn ->
      try do
        Process.unregister(:regra_mem_receiver)
      rescue
        _ -> :ok
      end
    end)

    {:ok, _} = Fato.start_link(:regra_mem_a, 10)
    {:ok, _} = Fato.start_link(:regra_mem_b, 20)

    defmodule RegraMemMod do
      def avaliar(mem), do: mem[:regra_mem_a] == 10 and mem[:regra_mem_b] == 20

      def executar(mem),
        do:
          send(
            Process.whereis(:regra_mem_receiver),
            {:exec, mem[:regra_mem_a], mem[:regra_mem_b]}
          )
    end

    {:ok, _} = Regra.start_link([:regra_mem_a, :regra_mem_b], RegraMemMod)
    # Memória inicial já é 10,20; `atualizar` com o mesmo valor não notifica (dedup no Fato).
    Fato.atualizar(:regra_mem_a, 9)
    Fato.atualizar(:regra_mem_a, 10)
    assert_receive {:exec, 10, 20}, 500
  end

  test "regra with instigation_list runs task when condition fires" do
    Process.register(self(), :regra_inst_receiver)

    on_exit(fn ->
      try do
        Process.unregister(:regra_inst_receiver)
      rescue
        _ -> :ok
      end
    end)

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

    # Evitar dedup (fatos iniciam em 0) e espaçar para não fundir contagens no debounce da Regra.
    Fato.atualizar(f1, 5)
    Process.sleep(15)
    Fato.atualizar(f2, 6)
    Process.sleep(15)
    Fato.atualizar(f1, 1)
    Process.sleep(15)
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

  test "drains notificacoes_lote coalesced after a single notificacao", %{f1: f1, f2: f2} do
    hit = :erlang.make_ref()
    test_pid = self()

    {:ok, pid} =
      Regra.start_link(
        [f1, f2],
        fn mem -> Map.get(mem, f1) == 1 and Map.get(mem, f2) == 2 end,
        fn _mem -> send(test_pid, hit) end
      )

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(15)
    send(pid, {:notificacao, f1, 1})
    send(pid, {:notificacoes_lote, %{f2 => 2}})
    assert_receive ^hit, 500
  end

  test "regra fires from atualizar_lote with single notificacoes_lote", %{f1: f1, f2: f2} do
    hit = :erlang.make_ref()
    test_pid = self()

    {:ok, _} =
      Regra.start_link(
        [f1, f2],
        fn mem -> Map.get(mem, f1) == 1 and Map.get(mem, f2) == 2 end,
        fn _mem -> send(test_pid, hit) end
      )

    Process.sleep(30)
    Fato.atualizar_lote(%{f1 => 1, f2 => 2})
    assert_receive ^hit, 500
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

  test "start_link/2 with module delegates to start_link/3 with empty opts" do
    Process.register(self(), :regra_sl2_parent)

    on_exit(fn ->
      try do
        Process.unregister(:regra_sl2_parent)
      rescue
        _ -> :ok
      end
    end)

    {:ok, fa} = Fato.start_link(:regra_sl2_f, 0)

    defmodule RegraSl2Mod do
      def avaliar(mem), do: mem[:regra_sl2_f] == 1
      def executar(_m), do: send(Process.whereis(:regra_sl2_parent), :sl2_hit)
    end

    {:ok, pid} = Regra.start_link([:regra_sl2_f], RegraSl2Mod)
    on_exit(fn -> Process.exit(pid, :normal) end)
    on_exit(fn -> Process.exit(fa, :normal) end)
    Fato.atualizar(:regra_sl2_f, 1)
    assert_receive :sl2_hit, 500
  end

  test "ignores unknown messages" do
    f = :"regra_junk_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(f, 0)
    {:ok, pid} = Regra.start_link([f], fn _ -> false end, fn _ -> :ok end)
    on_exit(fn -> Process.exit(pid, :normal) end)
    send(pid, :not_a_pon_message)
    Process.sleep(20)
    assert Process.alive?(pid)
  end

  test "code_change callback returns unchanged state" do
    st = %{
      fatos: [:x],
      memoria: %{},
      condicao: nil,
      acao: nil,
      modulo: nil,
      instigation_list: [],
      edge_triggered: false,
      ultima_condicao: false,
      estatisticas_notificacoes: 0,
      estatisticas_execucoes: 0
    }

    assert {:ok, ^st} = Tec0301Pon.PON.Regra.code_change(:v1, st, [])
  end

  test "edge_triggered module rule fires only on rising edge" do
    Process.register(self(), :regra_edge_recv)

    on_exit(fn ->
      try do
        Process.unregister(:regra_edge_recv)
      rescue
        _ -> :ok
      end
    end)

    {:ok, _} = Fato.start_link(:regra_edge_f, false)

    defmodule RegraEdgeTriggeredMod do
      def avaliar(m), do: m[:regra_edge_f] == true
      def executar(_m), do: send(Process.whereis(:regra_edge_recv), :edge)
    end

    {:ok, pid} =
      Regra.start_link([:regra_edge_f], RegraEdgeTriggeredMod, edge_triggered: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(15)
    Fato.atualizar(:regra_edge_f, true)
    assert_receive :edge, 400
    Fato.atualizar(:regra_edge_f, true)
    Process.sleep(40)
    refute_receive :edge, 50
    Fato.atualizar(:regra_edge_f, false)
    Process.sleep(15)
    Fato.atualizar(:regra_edge_f, true)
    assert_receive :edge, 400
  end
end
