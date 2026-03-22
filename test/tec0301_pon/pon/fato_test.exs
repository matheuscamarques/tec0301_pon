defmodule Tec0301Pon.PON.FatoTest do
  use Tec0301Pon.PonCase
  alias Tec0301Pon.PON.Fato

  setup do
    name = :"fato_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 10)
    on_exit(fn -> Process.exit(pid, :normal) end)
    %{name: name}
  end

  test "start_link stores initial value", %{name: name} do
    assert Fato.obter(name) == 10
  end

  test "atualizar changes value", %{name: name} do
    Fato.atualizar(name, 20)
    Process.sleep(10)
    assert Fato.obter(name) == 20
  end

  test "atualizar_lote updates values and sends one notificacoes_lote per subscriber" do
    a = :"fato_lote_a_#{System.unique_integer([:positive])}"
    b = :"fato_lote_b_#{System.unique_integer([:positive])}"
    {:ok, pa} = Fato.start_link(a, 0)
    {:ok, pb} = Fato.start_link(b, 0)

    on_exit(fn ->
      Process.exit(pa, :normal)
      Process.exit(pb, :normal)
    end)

    Registry.register(Tec0301Pon.PON.PubSub, a, [])
    Registry.register(Tec0301Pon.PON.PubSub, b, [])

    Fato.atualizar_lote(%{a => 7, b => 8})
    assert_receive {:notificacoes_lote, m}, 500
    assert m[a] == 7 and m[b] == 8
    refute_receive {:notificacao, _, _}, 20
    assert Fato.obter(a) == 7
    assert Fato.obter(b) == 8
  end

  test "atualizar_lote with many keys uses parallel path and coalesces one lote" do
    names =
      for i <- 1..5 do
        n = :"fato_lote_many_#{i}_#{System.unique_integer([:positive])}"
        {:ok, p} = Fato.start_link(n, 0)
        on_exit(fn -> Process.exit(p, :normal) end)
        Registry.register(Tec0301Pon.PON.PubSub, n, [])
        n
      end

    updates = Map.new(names, fn n -> {n, 1} end)
    Fato.atualizar_lote(updates)
    assert_receive {:notificacoes_lote, m}, 1_000
    assert map_size(m) == 5

    for n <- names do
      assert m[n] == 1
      assert Fato.obter(n) == 1
    end
  end

  test "atualizar dispatches notification to subscribers" do
    name = :"fato_notif_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(name, :a)
    Registry.register(Tec0301Pon.PON.PubSub, name, [])
    Fato.atualizar(name, :b)
    assert_receive {:notificacao, ^name, :b}, 500
  end

  test "atualizar notifies multiple subscribers" do
    name = :"fato_multi_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 0)
    on_exit(fn -> Process.exit(pid, :normal) end)
    parent = self()

    for _ <- 1..2 do
      spawn(fn ->
        Registry.register(Tec0301Pon.PON.PubSub, name, [])

        receive do
          msg -> send(parent, msg)
        end
      end)
    end

    Process.sleep(50)
    Fato.atualizar(name, 1)
    assert_receive {:notificacao, ^name, 1}, 500
    assert_receive {:notificacao, ^name, 1}, 500
  end

  test "estatisticas returns update count and reset_estatisticas zeros it" do
    name = :"fato_stats_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 0)
    on_exit(fn -> Process.exit(pid, :normal) end)
    assert Fato.estatisticas(name) == %{dispatches: 0, noop_updates: 0}
    Fato.atualizar(name, 1)
    Fato.atualizar(name, 2)
    Fato.atualizar(name, 3)
    Process.sleep(20)
    assert Fato.estatisticas(name) == %{dispatches: 3, noop_updates: 0}
    Fato.reset_estatisticas(name)
    Process.sleep(10)
    assert Fato.estatisticas(name) == %{dispatches: 0, noop_updates: 0}
  end

  test "atualizar with unchanged value does not increment estatisticas or dispatch" do
    name = :"fato_same_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 5)
    on_exit(fn -> Process.exit(pid, :normal) end)
    Registry.register(Tec0301Pon.PON.PubSub, name, [])
    Fato.atualizar(name, 5)
    Fato.atualizar(name, 5)
    Process.sleep(20)
    assert Fato.estatisticas(name) == %{dispatches: 0, noop_updates: 2}
    assert Fato.obter(name) == 5
    refute_receive {:notificacao, _, _}, 20
  end

  test "atualizar accepts nil, map, list and obter returns last value" do
    name = :"fato_vals_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, :init)
    on_exit(fn -> Process.exit(pid, :normal) end)
    Fato.atualizar(name, nil)
    Process.sleep(10)
    assert Fato.obter(name) == nil
    Fato.atualizar(name, %{a: 1})
    Process.sleep(10)
    assert Fato.obter(name) == %{a: 1}
    Fato.atualizar(name, [1, 2, 3])
    Process.sleep(10)
    assert Fato.obter(name) == [1, 2, 3]
  end

  test "atualizar with no subscribers does not fail" do
    name = :"fato_nosub_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 0)
    on_exit(fn -> Process.exit(pid, :normal) end)
    Fato.atualizar(name, 1)
    Process.sleep(10)
    assert Fato.obter(name) == 1
  end

  test "start_link with already registered name returns already_started" do
    name = :"fato_dup_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 0)
    on_exit(fn -> Process.exit(pid, :normal) end)
    assert {:error, {:already_started, ^pid}} = Fato.start_link(name, 99)
  end

  test "ets_table_name returns the named ETS table atom" do
    assert Fato.ets_table_name() == :tec0301_pon_fato_values
  end

  test "ensure_ets! is idempotent" do
    tab = Fato.ets_table_name()
    assert :ok = Fato.ensure_ets!()
    assert :ok = Fato.ensure_ets!()
    assert :ets.whereis(tab) != :undefined
  end

  test "obter falls back to GenServer when ETS row is missing" do
    name = :"fato_ets_miss_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, :from_gs)
    on_exit(fn -> Process.exit(pid, :normal) end)
    assert :ets.delete(Fato.ets_table_name(), name) == true
    assert Fato.obter(name) == :from_gs
  end

  test "atualizar_sem_dispatch via call updates value without dispatch" do
    name = :"fato_sem_disp_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 1)
    on_exit(fn -> Process.exit(pid, :normal) end)
    Registry.register(Tec0301Pon.PON.PubSub, name, [])
    assert GenServer.call(name, {:atualizar_sem_dispatch, 2}) == :changed
    refute_receive {:notificacao, _, _}, 30
    assert GenServer.call(name, {:atualizar_sem_dispatch, 2}) == :unchanged
    assert Fato.obter(name) == 2
  end

  test "atualizar with missing ETS row still updates GenServer (ets_put no-ops on missing table)" do
    name = :"fato_ets_put_rescue_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 0)
    on_exit(fn -> Process.exit(pid, :normal) end)
    on_exit(fn -> Fato.ensure_ets!() end)
    tab = Fato.ets_table_name()
    assert :ets.delete(tab, name) == true
    Fato.atualizar(name, 5)
    Process.sleep(15)
    assert GenServer.call(name, :obter) == 5
    Fato.ensure_ets!()
    assert Fato.obter(name) == 5
  end

  test "code_change callback returns unchanged state" do
    st = %{nome: :cc_fato, valor: :x, estatisticas: 0}
    assert {:ok, ^st} = Tec0301Pon.PON.Fato.code_change(:v1, st, [])
  end

  test "ets_put rescues ArgumentError when ETS table is missing at init" do
    tab = Fato.ets_table_name()
    on_exit(fn -> Fato.ensure_ets!() end)
    :ets.delete(tab)
    name = :"fato_init_no_ets_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 0)
    on_exit(fn -> Process.exit(pid, :normal) end)
    Fato.ensure_ets!()
    assert Fato.obter(name) == 0
  end

  test "atualizar_lote with empty map returns :ok" do
    assert Fato.atualizar_lote(%{}) == :ok
  end
end
