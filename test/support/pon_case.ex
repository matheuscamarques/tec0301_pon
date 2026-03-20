defmodule Tec0301Pon.PonCase do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: false

      setup do
        :ok = Tec0301Pon.PON.Fato.ensure_ets!()
        :ok
      end
    end
  end
end
