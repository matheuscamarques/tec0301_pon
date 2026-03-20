defmodule Tec0301Pon.PON.ReteSpikeTest do
  use ExUnit.Case, async: true

  alias Tec0301Pon.PON.ReteSpike

  test "demo fires production when both conditions hold" do
    {_net, n} = ReteSpike.run_demo()
    assert n == 1
  end

  test "negative demo leaves agenda empty when join does not close" do
    {_net, n} = ReteSpike.run_negative_demo()
    assert n == 0
  end
end
