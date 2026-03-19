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
end
