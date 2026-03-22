defmodule Tec0301Pon.PON.StormPoc do
  @moduledoc """
  Agregação de contadores PON para POCs (dedup em `Fato`, drain em `Regra`).

  Usa `Tec0301Pon.Examples.SmartBrewery` quando a malha já foi iniciada (ex.: `SmartBreweryBridge`).
  """

  alias Tec0301Pon.Examples.SmartBrewery
  alias Tec0301Pon.PON.Fato
  alias Tec0301Pon.PON.Regra

  @doc """
  Soma `Fato.estatisticas/1` para os 57 fatos da Smart Brewery.
  """
  def aggregate_fatos_smart_brewery do
    Enum.reduce(SmartBrewery.fatos_names(), %{dispatches: 0, noop_updates: 0}, fn name, acc ->
      s = Fato.estatisticas(name)

      %{
        dispatches: acc.dispatches + s.dispatches,
        noop_updates: acc.noop_updates + s.noop_updates
      }
    end)
  end

  @doc """
  Soma `Regra.estatisticas/1` para os PIDs guardados em `:smart_brewery_regra_pids`.
  """
  def aggregate_regras_smart_brewery do
    Enum.reduce(
      SmartBrewery.regra_pids(),
      %{notificacoes: 0, execucoes: 0, drained_messages: 0, avaliacoes: 0},
      fn pid, acc ->
        s = Regra.estatisticas(pid)

        %{
          notificacoes: acc.notificacoes + s.notificacoes,
          execucoes: acc.execucoes + s.execucoes,
          drained_messages: acc.drained_messages + s.drained_messages,
          avaliacoes: acc.avaliacoes + s.avaliacoes
        }
      end
    )
  end

  @doc """
  Zera contadores de fatos e regras da Smart Brewery (útil antes de um bloco de medição).
  """
  def reset_smart_brewery_counters do
    for name <- SmartBrewery.fatos_names() do
      Fato.reset_estatisticas(name)
    end

    for pid <- SmartBrewery.regra_pids(), is_pid(pid) do
      Regra.reset_estatisticas(pid)
    end

    :ok
  end
end
