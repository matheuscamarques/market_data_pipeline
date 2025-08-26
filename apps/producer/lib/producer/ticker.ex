defmodule Producer.Ticker do
  use GenServer
  require Logger

  @moduledoc """
  Quantum-inspired stock ticker simulator.

  Each stock symbol evolves based on:
    * **Base price** — the long-term value the stock fluctuates around.
    * **Drift** — a slow upward or downward trend over time.
    * **Oscillation (superposition)** — a combination of sine and cosine waves,
      simulating complex, less predictable cycles (quantum superposition analogy).
    * **Noise** — random perturbations that add uncertainty.

  This produces continuous but irregular price movements that feel closer to real markets.
  """

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    symbols_list = Keyword.get(opts, :symbols, ["AAPL", "GOOGL", "MSFT", "BTC"])
    interval = Keyword.get(opts, :interval, 1000)

    symbols_state =
      Enum.into(symbols_list, %{}, fn symbol ->
        {symbol, initial_symbol_state(symbol)}
      end)

    state = %{symbols: symbols_state, interval: interval}
    schedule_tick(interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    updated_symbols =
      Map.new(state.symbols, fn {symbol, symbol_data} ->
        {symbol, update_symbol_data(symbol_data)}
      end)

    updated_symbols
    |> Task.async_stream(
      fn {symbol, symbol_data} ->
        payload = %{
          symbol: symbol,
          value: symbol_data.current_value,
          timestamp: DateTime.utc_now()
        }

        routing_key = "stocks.#{symbol}"
        Logger.info("Generated #{symbol}: #{symbol_data.current_value}")
        Producer.Publisher.publish(routing_key, payload)
      end,
      max_concurrency: 10,
      timeout: 5000,
      on_timeout: :kill_task
    )
    |> Stream.run()

    schedule_tick(state.interval)
    {:noreply, %{state | symbols: updated_symbols}}
  end

  # --- Initial states ---
  defp initial_symbol_state("BTC") do
    %{
      base: 60_000.0 + :rand.uniform() * 5000.0,
      amplitude: 2500.0 + :rand.uniform() * 1000.0,
      angle: :rand.uniform() * :math.pi() * 2,
      step: 0.1 + :rand.uniform() * 0.1,
      drift_factor: (:rand.uniform() - 0.5) * 0.5,
      # slight random weighting for superposition of sin/cos
      phase_mix: :rand.uniform(),
      current_value: 0.0
    }
  end

  defp initial_symbol_state(_symbol) do
    %{
      base: 100.0 + :rand.uniform() * 400.0,
      amplitude: 5.0 + :rand.uniform() * 20.0,
      angle: :rand.uniform() * :math.pi() * 2,
      step: 0.05 + :rand.uniform() * 0.1,
      drift_factor: (:rand.uniform() - 0.5) * 0.1,
      phase_mix: :rand.uniform(),
      current_value: 0.0
    }
  end

  # --- Quantum-inspired update ---
  defp update_symbol_data(symbol_data) do
    new_angle = symbol_data.angle + symbol_data.step

    # Base with drift + small Gaussian noise
    new_base = symbol_data.base + symbol_data.drift_factor + (:rand.normal() * 0.05)

    # Weighted combination of sine and cosine
    sin_component = symbol_data.phase_mix * :math.sin(new_angle)
    cos_component = (1.0 - symbol_data.phase_mix) * :math.cos(new_angle)

    oscillation = symbol_data.amplitude * (sin_component + cos_component)

    # Random noise: uncertainty
    noise = :rand.normal() * (symbol_data.amplitude / 20)

    new_value = new_base + oscillation + noise

    %{
      symbol_data
      | angle: new_angle,
        base: new_base,
        current_value: Float.round(new_value, 2)
    }
  end

  defp schedule_tick(interval),
    do: Process.send_after(self(), :tick, interval)
end
