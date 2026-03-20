defmodule Tec0301Pon.PON.PremissaTest do
  use Tec0301Pon.PonCase
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.PON.Premissa

  test "with criar_fato_derivado true creates derived fact and updates when condition changes" do
    fonte = :"prem_criar_fonte_#{System.unique_integer([:positive])}"
    derivado = :"prem_criar_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(fonte, 0)

    {:ok, prem_pid} =
      Premissa.start_link(derivado, [fonte], fn m -> (m[fonte] || 0) >= 10 end,
        criar_fato_derivado: true
      )

    on_exit(fn -> Process.exit(prem_pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(derivado) == false
    Fato.atualizar(fonte, 10)
    Process.sleep(20)
    assert Fato.obter(derivado) == true
    Fato.atualizar(fonte, 5)
    Process.sleep(20)
    assert Fato.obter(derivado) == false
    Fato.atualizar(fonte, 20)
    Process.sleep(20)
    assert Fato.obter(derivado) == true
  end

  test "without criar_fato_derivado updates existing derived fact when condition changes" do
    fonte = :"prem_nocriar_fonte_#{System.unique_integer([:positive])}"
    derivado = :"prem_nocriar_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(fonte, 0)
    {:ok, _} = Fato.start_link(derivado, false)
    {:ok, prem_pid} = Premissa.start_link(derivado, [fonte], fn m -> (m[fonte] || 0) >= 5 end, [])
    on_exit(fn -> Process.exit(prem_pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(derivado) == false
    Fato.atualizar(fonte, 5)
    Process.sleep(20)
    assert Fato.obter(derivado) == true
  end

  test "with two source facts updates derived from both" do
    f1 = :"prem_two_f1_#{System.unique_integer([:positive])}"
    f2 = :"prem_two_f2_#{System.unique_integer([:positive])}"
    derivado = :"prem_two_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(f1, 0)
    {:ok, _} = Fato.start_link(f2, 0)

    {:ok, prem_pid} =
      Premissa.start_link(
        derivado,
        [f1, f2],
        fn m -> (m[f1] || 0) >= (m[f2] || 0) end,
        criar_fato_derivado: true
      )

    on_exit(fn -> Process.exit(prem_pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(derivado) == true
    Fato.atualizar(f2, 10)
    Process.sleep(20)
    assert Fato.obter(derivado) == false
    Fato.atualizar(f1, 10)
    Process.sleep(20)
    assert Fato.obter(derivado) == true
  end

  test "does not update derived fact when condition result unchanged" do
    fonte = :"prem_unchanged_#{System.unique_integer([:positive])}"
    derivado = :"prem_unchanged_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(fonte, 10)

    {:ok, prem_pid} =
      Premissa.start_link(derivado, [fonte], fn m -> (m[fonte] || 0) >= 10 end,
        criar_fato_derivado: true
      )

    on_exit(fn -> Process.exit(prem_pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(derivado) == true
    Fato.atualizar(fonte, 11)
    Fato.atualizar(fonte, 12)
    Process.sleep(30)
    assert Fato.obter(derivado) == true
  end

  test "criar_fato_derivado does not start_link when derived fact already registered" do
    fonte = :"prem_exists_fonte_#{System.unique_integer([:positive])}"
    derivado = :"prem_exists_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(fonte, 0)
    {:ok, _} = Fato.start_link(derivado, true)

    {:ok, prem_pid} =
      Premissa.start_link(derivado, [fonte], fn m -> (m[fonte] || 0) >= 0 end,
        criar_fato_derivado: true
      )

    on_exit(fn -> Process.exit(prem_pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(derivado) == true
  end

  test "start_link/3 uses default empty opts list" do
    fonte = :"prem_defopts_f_#{System.unique_integer([:positive])}"
    derivado = :"prem_defopts_d_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(fonte, 0)

    {:ok, prem_pid} =
      Premissa.start_link(derivado, [fonte], fn _ -> false end)

    on_exit(fn -> Process.exit(prem_pid, :normal) end)
    Process.sleep(15)
    assert Process.alive?(prem_pid)
  end

  test "ignores unrelated messages" do
    fonte = :"prem_junk_f_#{System.unique_integer([:positive])}"
    derivado = :"prem_junk_d_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(fonte, 0)

    {:ok, prem_pid} =
      Premissa.start_link(derivado, [fonte], fn _ -> false end, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(prem_pid, :normal) end)
    send(prem_pid, :noise)
    Process.sleep(15)
    assert Process.alive?(prem_pid)
  end
end
