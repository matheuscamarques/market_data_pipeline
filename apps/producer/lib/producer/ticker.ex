defmodule Producer.Ticker do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    symbols = Keyword.get(opts, :symbols, ["AAPL", "GOOGL", "MSFT"])
    interval = Keyword.get(opts, :interval, 1000)

    state = %{
      symbols: symbols,
      angle: 0.0,
      step: 0.1,
      interval: interval
    }

    schedule_tick(interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    new_angle = state.angle + state.step

    state.symbols
    |> Task.async_stream(
      fn symbol ->
        value = generate_value(symbol, new_angle)
        Logger.info("Generated value for #{symbol}: #{value}")

        payload = %{
          symbol: symbol,
          value: value,
          timestamp: DateTime.utc_now()
        }

        routing_key = "stocks.#{symbol}"
        Producer.Publisher.publish(routing_key, payload)
      end,
      max_concurrency: 10,
      timeout: 5000,
      on_timeout: :kill_task
    )
    |> Stream.run()

    schedule_tick(state.interval)
    {:noreply, %{state | angle: new_angle}}
  end

  defp generate_value(_symbol, angle) do
    base_price = 100.0 + :rand.uniform() * 50.0
    amplitude = 10.0 + :rand.uniform() * 5.0
    noise = :rand.normal() * 0.5

    base_price + amplitude * :math.sin(angle) + noise
  end

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end
end
