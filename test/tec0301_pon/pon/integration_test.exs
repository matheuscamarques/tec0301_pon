defmodule Tec0301Pon.PON.IntegrationTest do
  @moduledoc """
  Integration test: full PON graph with fatos, premissas (DSL), regras (DSL) and Service.
  """
  use Tec0301Pon.PonCase
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.PON.Service

  defmodule GrafoCompleto do
    use Tec0301Pon.PON.Builder

    defpremissa(Alta,
      watch: [:int_a],
      when: (memoria[:int_a] || 0) >= 10,
      derive: :int_derivado,
      criar_fato: true
    )

    defpremissa(Baixa,
      watch: [:int_b],
      when: (memoria[:int_b] || 0) < 5,
      derive: :int_derivado_b,
      criar_fato: true
    )

    defrule(R1,
      watch: [:int_derivado],
      when: memoria[:int_derivado] == true,
      do: send(Process.whereis(:int_receiver), :r1_fired)
    )

    defrule(R2,
      watch: [:int_derivado_b, :int_c],
      when: memoria[:int_derivado_b] == true and memoria[:int_c] == :go,
      do: send(Process.whereis(:int_receiver), :r2_fired)
    )
  end

  setup do
    Process.register(self(), :int_receiver)

    on_exit(fn ->
      try do
        Process.unregister(:int_receiver)
      rescue
        _ -> :ok
      end
    end)

    case Service.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Service.reset_estatisticas()
    :ok
  end

  test "full graph: fatos, premissas, regras, Service statistics" do
    {:ok, _} = Fato.start_link(:int_a, 0)
    {:ok, _} = Fato.start_link(:int_b, 0)
    {:ok, _} = Fato.start_link(:int_c, :idle)
    Service.registrar_fato(:int_a, :int_a)
    Service.registrar_fato(:int_b, :int_b)
    Service.registrar_fato(:int_c, :int_c)
    {:ok, _} = GrafoCompleto.Alta.start_link()
    {:ok, _} = GrafoCompleto.Baixa.start_link()
    {:ok, r1_pid} = GrafoCompleto.R1.start_link()
    {:ok, r2_pid} = GrafoCompleto.R2.start_link()
    Service.registrar_regra(:r1, r1_pid)
    Service.registrar_regra(:r2, r2_pid)

    Fato.atualizar(:int_a, 5)
    Process.sleep(30)
    refute_receive :r1_fired, 100
    Fato.atualizar(:int_a, 10)
    Process.sleep(30)
    assert_receive :r1_fired, 500

    Fato.atualizar(:int_b, 3)
    Process.sleep(30)
    refute_receive :r2_fired, 100
    Fato.atualizar(:int_c, :go)
    Process.sleep(30)
    assert_receive :r2_fired, 500

    s = Service.estatisticas_globais()
    assert s.fatos.dispatches >= 0
    assert s.regras.notificacoes >= 0
    assert s.regras.execucoes >= 2

    Service.reset_estatisticas()
    Process.sleep(20)
    s2 = Service.estatisticas_globais()
    assert s2.fatos == %{dispatches: 0, noop_updates: 0}
    assert s2.regras.notificacoes == 0
    assert s2.regras.execucoes == 0
    assert s2.regras.drained_messages == 0
    assert s2.regras.avaliacoes == 0
  end

  test "graph invariants hold across pseudo-random sequence of updates" do
    {:ok, _} = Fato.start_link(:int_a, 0)
    {:ok, _} = Fato.start_link(:int_b, 0)
    {:ok, _} = Fato.start_link(:int_c, :idle)

    {:ok, _} = GrafoCompleto.Alta.start_link()
    {:ok, _} = GrafoCompleto.Baixa.start_link()

    Enum.each(1..60, fn i ->
      a = rem(i * 7, 16)
      b = rem(i * 5, 9)
      c = if(rem(i, 3) == 0, do: :go, else: :idle)

      Fato.atualizar(:int_a, a)
      Fato.atualizar(:int_b, b)
      Fato.atualizar(:int_c, c)
      Process.sleep(6)

      assert Fato.obter(:int_derivado) == a >= 10
      assert Fato.obter(:int_derivado_b) == b < 5
    end)
  end

  test "concurrent lote bursts keep service responsive and queues drain" do
    {:ok, _} = Fato.start_link(:int_a, 0)
    {:ok, _} = Fato.start_link(:int_b, 0)
    {:ok, _} = Fato.start_link(:int_c, :idle)
    Service.registrar_fato(:int_a, :int_a)
    Service.registrar_fato(:int_b, :int_b)
    Service.registrar_fato(:int_c, :int_c)

    {:ok, _} = GrafoCompleto.Alta.start_link()
    {:ok, _} = GrafoCompleto.Baixa.start_link()
    {:ok, r1_pid} = GrafoCompleto.R1.start_link()
    {:ok, r2_pid} = GrafoCompleto.R2.start_link()
    Service.registrar_regra(:r1_burst, r1_pid)
    Service.registrar_regra(:r2_burst, r2_pid)

    tasks =
      for offset <- 1..4 do
        Task.async(fn ->
          Enum.each(1..20, fn i ->
            a = rem(i + offset * 3, 15)
            b = rem(i + offset, 8)
            c = if(rem(i + offset, 2) == 0, do: :go, else: :idle)
            Fato.atualizar_lote(%{int_a: a, int_b: b, int_c: c})
          end)
        end)
      end

    Enum.each(tasks, &Task.await(&1, 5_000))
    Fato.atualizar_lote(%{int_a: 12, int_b: 3, int_c: :go})
    assert Service.wait_until_queues_empty(1_500) == :ok

    s = Service.estatisticas_globais()
    assert s.regras.notificacoes > 0
    assert s.regras.execucoes > 0
  end
end
