defmodule Tec0301Pon do
  @moduledoc """
  Framework PON (Paradigma Orientado a Notificações) em Elixir/BEAM.

  - **Núcleo:** `Tec0301Pon.PON.Fato`, `Tec0301Pon.PON.Regra`, Registry como barramento de notificações.
  - **DSL:** `use Tec0301Pon.PON.Builder` e macro `defrule` (ver `Tec0301Pon.PON.Builder`).
  - **Hexagonal:** Ports em `Tec0301Pon.Ports.*`, adaptadores em `Tec0301Pon.Adapters.*`.

  Arquitetura e exemplos (Estufa) estão descritos em `docs/artigos/02_motor_pon_beam.md`.
  Fundamentação teórica: recursos em `docs/recursos/` (ver README nessa pasta).
  """

  @doc """
  Hello world.

  ## Examples

      iex> Tec0301Pon.hello()
      :world

  """
  def hello do
    :world
  end
end
