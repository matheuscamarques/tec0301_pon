defmodule Tec0301Pon.PON.ServiceTest do
  use ExUnit.Case, async: false
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.PON.Regra
  alias Tec0301Pon.PON.Service

  setup do
    case Service.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    :ok
  end

  test "start_link starts the service" do
    assert Process.whereis(Service) != nil
  end

  test "registrar_fato and registrar_regra do not crash" do
    Service.reset_estatisticas()
    n = :"svc_reg_f_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(n, 0)
    Service.registrar_fato(n, n)
    {:ok, regra_pid} = Regra.start_link([n], fn _ -> false end, fn _ -> :ok end)
    Service.registrar_regra(:r1, regra_pid)
    Process.sleep(10)
    s = Service.estatisticas_globais()
    assert is_map(s)
    assert Map.has_key?(s, :fatos)
    assert Map.has_key?(s, :regras)
    assert is_map(s.regras)
    assert Map.has_key?(s.regras, :notificacoes)
    assert Map.has_key?(s.regras, :execucoes)
  end

  test "estatisticas_globais reflects updates and firings" do
    Service.reset_estatisticas()
    n = :"svc_glob_f_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(n, 0)
    Service.registrar_fato(n, n)
    hit = :erlang.make_ref()
    test_pid = self()
    {:ok, regra_pid} =
      Regra.start_link(
        [n],
        fn m -> m[n] == 2 end,
        fn _ -> send(test_pid, hit) end
      )
    Service.registrar_regra(:r_glob, regra_pid)
    Fato.atualizar(n, 1)
    Fato.atualizar(n, 2)
    assert_receive ^hit, 500
    Process.sleep(20)
    s = Service.estatisticas_globais()
    assert s.fatos >= 2
    assert s.regras.notificacoes >= 2
    assert s.regras.execucoes >= 1
  end

  test "reset_estatisticas zeros all counters" do
    Service.reset_estatisticas()
    n = :"svc_rst_f_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(n, 0)
    Service.registrar_fato(n, n)
    {:ok, regra_pid} = Regra.start_link([n], fn _ -> false end, fn _ -> :ok end)
    Service.registrar_regra(:r_rst, regra_pid)
    Fato.atualizar(n, 1)
    Fato.atualizar(n, 2)
    Process.sleep(20)
    _s_before = Service.estatisticas_globais()
    Service.reset_estatisticas()
    Process.sleep(20)
    s_after = Service.estatisticas_globais()
    assert s_after.fatos == 0
    assert s_after.regras.notificacoes == 0
    assert s_after.regras.execucoes == 0
  end

  test "wait_until_queues_empty returns ok when queues are empty" do
    Service.reset_estatisticas()
    n = :"svc_wait_f_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(n, 0)
    {:ok, regra_pid} = Regra.start_link([n], fn _ -> false end, fn _ -> :ok end)
    Service.registrar_regra(:r_wait, regra_pid)
    Process.sleep(50)
    assert Service.wait_until_queues_empty(200) == :ok
  end
end
