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
end
