defmodule Tec0301Pon.PON.FanoutTest do
  use Tec0301Pon.PonCase

  alias Tec0301Pon.PON.{Fanout, Fato}

  test "atualizar_lote with empty map returns :ok" do
    assert Fanout.atualizar_lote(%{}) == :ok
  end

  test "merge_async_stream_chunk raises on task exit tuple" do
    assert_raise RuntimeError, ~r/Fanout\.atualizar_lote task failed/, fn ->
      Fanout.__test_merge_async_stream_chunk({:exit, :some_reason}, %{})
    end

    assert Fanout.__test_merge_async_stream_chunk({:ok, nil}) == %{}
    assert Fanout.__test_merge_async_stream_chunk({:ok, {:f, 1}}, %{}) == %{f: 1}
  end

  test "parallel path records unchanged entries and notifies only when at least one changes" do
    names =
      for i <- 1..5 do
        n = :"fan_par_uc_#{i}_#{System.unique_integer([:positive])}"
        {:ok, p} = Fato.start_link(n, 1)
        on_exit(fn -> Process.exit(p, :normal) end)
        n
      end

    assert Fanout.atualizar_lote(Map.new(names, &{&1, 1})) == :ok
    assert Fanout.atualizar_lote(Map.new(names, &{&1, 2})) == :ok
  end

  test "atualizar_lote when all values unchanged does not notify subscribers" do
    a = :"fanout_same_a_#{System.unique_integer([:positive])}"
    {:ok, pa} = Fato.start_link(a, 1)

    on_exit(fn -> Process.exit(pa, :normal) end)

    Registry.register(Tec0301Pon.PON.PubSub, a, [])
    assert Fanout.atualizar_lote(%{a => 1}) == :ok
    refute_receive {:notificacoes_lote, _}, 50
  end
end
