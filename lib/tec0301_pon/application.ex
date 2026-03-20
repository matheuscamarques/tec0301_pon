defmodule Tec0301Pon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ok = Tec0301Pon.PON.Fato.ensure_ets!()

    children = [
      {Registry,
       keys: :duplicate, name: Tec0301Pon.PON.PubSub, partitions: System.schedulers_online()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tec0301Pon.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
