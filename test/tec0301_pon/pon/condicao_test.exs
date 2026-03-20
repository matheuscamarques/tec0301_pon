defmodule Tec0301Pon.PON.CondicaoTest do
  use Tec0301Pon.PonCase
  alias Tec0301Pon.PON.{Condicao, Fato}

  test "merge all requires every watched fact === true" do
    a = :"cond_all_a_#{System.unique_integer([:positive])}"
    b = :"cond_all_b_#{System.unique_integer([:positive])}"
    d = :"cond_all_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, false)
    {:ok, _} = Fato.start_link(b, false)

    {:ok, pid} =
      Condicao.start_link(d, [a, b], merge: :all, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(d) == false
    Fato.atualizar(a, true)
    Process.sleep(20)
    assert Fato.obter(d) == false
    Fato.atualizar(b, true)
    Process.sleep(20)
    assert Fato.obter(d) == true
    Fato.atualizar(a, false)
    Process.sleep(20)
    assert Fato.obter(d) == false
  end

  test "merge any is true when at least one watched fact === true" do
    a = :"cond_any_a_#{System.unique_integer([:positive])}"
    b = :"cond_any_b_#{System.unique_integer([:positive])}"
    d = :"cond_any_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, false)
    {:ok, _} = Fato.start_link(b, false)

    {:ok, pid} =
      Condicao.start_link(d, [a, b], merge: :any, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(d) == false
    Fato.atualizar(b, true)
    Process.sleep(20)
    assert Fato.obter(d) == true
    Fato.atualizar(b, false)
    Process.sleep(20)
    assert Fato.obter(d) == false
    Fato.atualizar(a, true)
    Process.sleep(20)
    assert Fato.obter(d) == true
  end

  test "combine_fn custom logic" do
    a = :"cond_cf_a_#{System.unique_integer([:positive])}"
    b = :"cond_cf_b_#{System.unique_integer([:positive])}"
    d = :"cond_cf_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, 1)
    {:ok, _} = Fato.start_link(b, 2)

    {:ok, pid} =
      Condicao.start_link(d, [a, b],
        combine_fn: fn m -> (m[a] || 0) + (m[b] || 0) > 5 end,
        criar_fato_derivado: true
      )

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(d) == false
    Fato.atualizar(a, 4)
    Process.sleep(20)
    assert Fato.obter(d) == true
  end

  test "start_link without merge or combine_fn raises" do
    assert_raise ArgumentError, fn ->
      Condicao.start_link(:x, [:a, :b], [])
    end
  end

  test "start_link/2 uses default opts and raises without merge or combine_fn" do
    d = :"cond_sl2_d_#{System.unique_integer([:positive])}"
    a = :"cond_sl2_a_#{System.unique_integer([:positive])}"

    assert_raise ArgumentError, fn ->
      Condicao.start_link(d, [a])
    end
  end

  test "start_link with both merge and combine_fn raises" do
    assert_raise ArgumentError, ~r/either :combine_fn or :merge/, fn ->
      Condicao.start_link(:x, [:a, :b],
        merge: :all,
        combine_fn: fn _ -> true end
      )
    end
  end

  test "criar_fato_derivado skips start when derived fact process already exists" do
    d = :"cond_exists_d_#{System.unique_integer([:positive])}"
    a = :"cond_exists_a_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, false)
    {:ok, _} = Fato.start_link(d, true)

    {:ok, pid} =
      Condicao.start_link(d, [a], merge: :any, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(20)
    assert Fato.obter(d) == false
  end

  test "ignores unrelated messages" do
    a = :"cond_junk_a_#{System.unique_integer([:positive])}"
    d = :"cond_junk_d_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, false)

    {:ok, pid} =
      Condicao.start_link(d, [a], merge: :all, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    send(pid, :noise)
    Process.sleep(15)
    assert Process.alive?(pid)
  end

  test "code_change callback returns unchanged state" do
    st = %{
      nome_fato_derivado: :d,
      fatos_fonte: [:a],
      combine_fn: fn _ -> false end,
      memoria: %{},
      resultado_anterior: nil,
      criar_fato_derivado: false
    }

    assert {:ok, out} = Tec0301Pon.PON.Condicao.code_change(:v1, st, [])
    assert out.nome_fato_derivado == :d
    assert out.fatos_fonte == [:a]
  end

  test "drains a notificacoes_lote message following a notificacao in the same batch" do
    a = :"cond_drain_a_#{System.unique_integer([:positive])}"
    b = :"cond_drain_b_#{System.unique_integer([:positive])}"
    d = :"cond_drain_d_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, false)
    {:ok, _} = Fato.start_link(b, false)

    {:ok, pid} =
      Condicao.start_link(d, [a, b], merge: :all, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(20)
    send(pid, {:notificacao, a, true})
    send(pid, {:notificacoes_lote, %{b => true}})
    Process.sleep(40)
    assert Fato.obter(d) == true
  end

  test "drains a notificacao following notificacoes_lote inside drain_notificacoes" do
    a = :"cond_drain2_a_#{System.unique_integer([:positive])}"
    b = :"cond_drain2_b_#{System.unique_integer([:positive])}"
    d = :"cond_drain2_d_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, false)
    {:ok, _} = Fato.start_link(b, false)

    {:ok, pid} =
      Condicao.start_link(d, [a, b], merge: :all, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(20)
    send(pid, {:notificacoes_lote, %{a => true}})
    send(pid, {:notificacao, b, true})
    Process.sleep(40)
    assert Fato.obter(d) == true
  end

  test "notificacoes_lote updates combined result" do
    a = :"cond_lote_a_#{System.unique_integer([:positive])}"
    b = :"cond_lote_b_#{System.unique_integer([:positive])}"
    d = :"cond_lote_deriv_#{System.unique_integer([:positive])}"
    {:ok, _} = Fato.start_link(a, false)
    {:ok, _} = Fato.start_link(b, false)

    {:ok, pid} =
      Condicao.start_link(d, [a, b], merge: :all, criar_fato_derivado: true)

    on_exit(fn -> Process.exit(pid, :normal) end)
    Process.sleep(20)
    send(pid, {:notificacoes_lote, %{a => true, b => true}})
    Process.sleep(30)
    assert Fato.obter(d) == true
  end
end
