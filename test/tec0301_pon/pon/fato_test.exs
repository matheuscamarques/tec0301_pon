defmodule Tec0301Pon.PON.FatoTest do
  use ExUnit.Case, async: false
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
    assert Fato.estatisticas(name) == 0
    Fato.atualizar(name, 1)
    Fato.atualizar(name, 2)
    Fato.atualizar(name, 3)
    Process.sleep(20)
    assert Fato.estatisticas(name) == 3
    Fato.reset_estatisticas(name)
    Process.sleep(10)
    assert Fato.estatisticas(name) == 0
  end

  test "estatisticas increments even when value is unchanged" do
    name = :"fato_same_#{System.unique_integer([:positive])}"
    {:ok, pid} = Fato.start_link(name, 5)
    on_exit(fn -> Process.exit(pid, :normal) end)
    Fato.atualizar(name, 5)
    Fato.atualizar(name, 5)
    Process.sleep(20)
    assert Fato.estatisticas(name) == 2
    assert Fato.obter(name) == 5
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
end
