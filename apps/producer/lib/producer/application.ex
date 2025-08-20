defmodule Producer.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Producer.Publisher,
      Producer.Ticker
    ]

    opts = [strategy: :one_for_one, name: Producer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
