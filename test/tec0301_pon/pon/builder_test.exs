defmodule Tec0301Pon.PON.BuilderTest do
  use ExUnit.Case, async: false
  alias Tec0301Pon.PON.Fato

  defmodule RegrasDeTeste do
    use Tec0301Pon.PON.Builder

    # Action sends to registered process so test can assert (executar runs in Regra process)
    defrule(Exemplo,
      watch: [:builder_f1, :builder_f2],
      when: memoria[:builder_f1] == 1 and memoria[:builder_f2] == 2,
      do: send(Process.whereis(:builder_test_receiver), :fired)
    )
  end

  defmodule PremissasDeTeste do
    use Tec0301Pon.PON.Builder

    defpremissa AcimaDeDez,
      watch: [:builder_prem_fonte],
      when: (memoria[:builder_prem_fonte] || 0) >= 10,
      derive: :builder_prem_derivado,
      criar_fato: true
  end

  defmodule RegrasWhenString do
    use Tec0301Pon.PON.Builder

    defrule(RegraX,
      watch: [:builder_ws_x],
      when: "memoria[:builder_ws_x] > 10",
      do: send(Process.whereis(:builder_ws_receiver), :fired_ws)
    )
  end

  defmodule RegrasInstigations do
    use Tec0301Pon.PON.Builder

    defrule(RegraInst,
      watch: [:builder_inst_f],
      when: memoria[:builder_inst_f] == 1,
      do: [instigations: [{Tec0301Pon.PON.BuilderTest.InstigationHelper, :notify, []}]]
    )
  end

  defmodule InstigationHelper do
    def notify do
      send(Process.whereis(:builder_inst_receiver), :instigation_fired)
    end
  end

  defmodule PremissasSemCriar do
    use Tec0301Pon.PON.Builder

    defpremissa AbaixoDeCinco,
      watch: [:builder_nocriar_fonte],
      when: (memoria[:builder_nocriar_fonte] || 0) < 5,
      derive: :builder_nocriar_derivado
  end

  defmodule RegraObservaDerivado do
    use Tec0301Pon.PON.Builder

    defpremissa FonteAlta,
      watch: [:builder_int_fonte],
      when: (memoria[:builder_int_fonte] || 0) >= 100,
      derive: :builder_int_derivado,
      criar_fato: true

    defrule(RegraQuandoDerivado,
      watch: [:builder_int_derivado],
      when: memoria[:builder_int_derivado] == true,
      do: send(Process.whereis(:builder_int_receiver), :regra_via_derivado)
    )
  end

  defmodule DuasPremissas do
    use Tec0301Pon.PON.Builder

    defpremissa P1,
      watch: [:builder_dp_a],
      when: (memoria[:builder_dp_a] || 0) > 0,
      derive: :builder_dp_deriv1,
      criar_fato: true

    defpremissa P2,
      watch: [:builder_dp_b],
      when: (memoria[:builder_dp_b] || 0) >= 0,
      derive: :builder_dp_deriv2,
      criar_fato: true
  end

  test "defrule generates module with start_link, avaliar, executar" do
    Process.register(self(), :builder_test_receiver)

    on_exit(fn ->
      try do
        Process.unregister(:builder_test_receiver)
      rescue
        _ -> :ok
      end
    end)

    assert true == RegrasDeTeste.Exemplo.avaliar(%{builder_f1: 1, builder_f2: 2})
    assert false == RegrasDeTeste.Exemplo.avaliar(%{builder_f1: 0, builder_f2: 2})

    RegrasDeTeste.Exemplo.executar(%{})
    assert_receive :fired, 200

    {:ok, _} = Fato.start_link(:builder_f1, 0)
    {:ok, _} = Fato.start_link(:builder_f2, 0)
    {:ok, _} = RegrasDeTeste.Exemplo.start_link()
    Fato.atualizar(:builder_f1, 1)
    Process.sleep(20)
    Fato.atualizar(:builder_f2, 2)
    assert_receive :fired, 500
  end

  test "defpremissa generates module with start_link and updates derived fact when condition changes" do
    {:ok, _} = Fato.start_link(:builder_prem_fonte, 0)
    {:ok, _} = PremissasDeTeste.AcimaDeDez.start_link()
    assert Fato.obter(:builder_prem_derivado) == false
    Fato.atualizar(:builder_prem_fonte, 5)
    Process.sleep(20)
    assert Fato.obter(:builder_prem_derivado) == false
    Fato.atualizar(:builder_prem_fonte, 10)
    Process.sleep(20)
    assert Fato.obter(:builder_prem_derivado) == true
    Fato.atualizar(:builder_prem_fonte, 3)
    Process.sleep(20)
    assert Fato.obter(:builder_prem_derivado) == false
  end

  test "defrule with when string compiles and avaliar evaluates expression" do
    assert true == RegrasWhenString.RegraX.avaliar(%{builder_ws_x: 11})
    assert false == RegrasWhenString.RegraX.avaliar(%{builder_ws_x: 5})
  end

  test "defrule with when string fires when fact satisfies expression" do
    Process.register(self(), :builder_ws_receiver)
    on_exit(fn -> try do Process.unregister(:builder_ws_receiver) rescue _ -> :ok end end)
    {:ok, _} = Fato.start_link(:builder_ws_x, 0)
    {:ok, _} = RegrasWhenString.RegraX.start_link()
    Fato.atualizar(:builder_ws_x, 11)
    assert_receive :fired_ws, 500
  end

  test "defrule with do: instigations runs task when rule fires" do
    Process.register(self(), :builder_inst_receiver)
    on_exit(fn -> try do Process.unregister(:builder_inst_receiver) rescue _ -> :ok end end)
    {:ok, _} = Fato.start_link(:builder_inst_f, 0)
    {:ok, _} = RegrasInstigations.RegraInst.start_link()
    Fato.atualizar(:builder_inst_f, 1)
    assert_receive :instigation_fired, 500
  end

  test "defpremissa without criar_fato updates existing derived fact" do
    {:ok, _} = Fato.start_link(:builder_nocriar_fonte, 0)
    {:ok, _} = Fato.start_link(:builder_nocriar_derivado, true)
    {:ok, _} = PremissasSemCriar.AbaixoDeCinco.start_link()
    Process.sleep(20)
    assert Fato.obter(:builder_nocriar_derivado) == true
    Fato.atualizar(:builder_nocriar_fonte, 10)
    Process.sleep(20)
    assert Fato.obter(:builder_nocriar_derivado) == false
  end

  test "regra watching derived fact fires when premissa updates it" do
    Process.register(self(), :builder_int_receiver)
    on_exit(fn -> try do Process.unregister(:builder_int_receiver) rescue _ -> :ok end end)
    {:ok, _} = Fato.start_link(:builder_int_fonte, 0)
    {:ok, _} = RegraObservaDerivado.FonteAlta.start_link()
    {:ok, _} = RegraObservaDerivado.RegraQuandoDerivado.start_link()
    Process.sleep(20)
    refute_receive :regra_via_derivado, 50
    Fato.atualizar(:builder_int_fonte, 100)
    assert_receive :regra_via_derivado, 500
  end

  test "multiple defpremissas in same module update their derived facts independently" do
    {:ok, _} = Fato.start_link(:builder_dp_a, 0)
    {:ok, _} = Fato.start_link(:builder_dp_b, 0)
    {:ok, _} = DuasPremissas.P1.start_link()
    {:ok, _} = DuasPremissas.P2.start_link()
    Process.sleep(20)
    assert Fato.obter(:builder_dp_deriv1) == false
    assert Fato.obter(:builder_dp_deriv2) == true
    Fato.atualizar(:builder_dp_a, 1)
    Process.sleep(20)
    assert Fato.obter(:builder_dp_deriv1) == true
    assert Fato.obter(:builder_dp_deriv2) == true
    Fato.atualizar(:builder_dp_b, -1)
    Process.sleep(20)
    assert Fato.obter(:builder_dp_deriv2) == false
  end
end
