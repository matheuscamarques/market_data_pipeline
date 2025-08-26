# Live Data Feed System: Real-Time Stock Price Stream

## 1. Overview
This project implements a real-time stock price streaming system.  
It simulates receiving stock price updates from an external service (mock API or random generator), broadcasts these updates to clients, and allows users to **subscribe to specific stock symbols** for continuous updates.

---

## 2. How to Run

### Using Docker Compose (Recommended)
```bash
docker-compose up --build
```

This will handle all dependencies and start the services.

### Manual Setup

#### Step 1 — Start the Producer

```bash
cd apps/producer
mix deps.get && mix compile
iex -S mix
```

#### Step 2 — Start the Phoenix Web Application

```bash
cd apps/phoenix_web
mix deps.get && mix compile
cd assets && npm install && cd ..
iex -S mix
```


At this point:

* The Producer generates and broadcasts stock price updates.
* The Phoenix Web app exposes a web interface to visualize the updates.

---

## 3. UI/UX

### Initial Design

![Initial Design](https://github.com/user-attachments/assets/a9fbbe0b-9377-47fc-8b1f-3393801e4ef0)

### Simplified Design

![Simplified Design](https://github.com/user-attachments/assets/9baebaf1-b94a-43a4-a14a-bfb0b19cc5f3)

---

## 4. System Scenario

The system must:

* Simulate real-time stock price updates.
* Allow clients to subscribe to specific stock symbols.
* Stream and broadcast updates only to interested subscribers.
* Maintain fault tolerance, ensuring stability even if processes crash.

---

## 5. Core Components

### 5.1 Stock Price Stream

* Generates continuous stock price updates.
* Prices are either randomly generated or fetched from a mock API.
* Each update is broadcasted to subscribers of the corresponding symbol.

### 5.2 Client Simulation

* A client subscribes to a symbol.
* Receives and displays incoming price updates.
* Represents how real applications (browsers, services) would consume this data.

### 5.3 Error Handling and Fault Tolerance

* System remains operational despite failures.
* Example: if a generator for one stock crashes, other symbols remain unaffected.

---

## 6. Producer.Ticker Module

The `Producer.Ticker` module is a **GenServer** responsible for generating quantum-inspired stock price updates.

### Key Concepts

* **Base Price:** Fundamental value around which the stock fluctuates.
* **Drift:** Long-term upward or downward trend.
* **Oscillation (Superposition):** Combination of sine and cosine waves to simulate complex, less predictable cycles.
* **Noise:** Random perturbations to add short-term unpredictability.

### Module Breakdown

```elixir
defmodule Producer.Ticker do
  use GenServer
  require Logger
```

* Uses `GenServer` for stateful, concurrent price simulation.
* Logs generated prices and publishes updates via `Producer.Publisher`.

#### Initialization

```elixir
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
```

* Defines **symbols** and **update interval**.
* Initializes each symbol with `initial_symbol_state/1`.
* Schedules recurring ticks for price updates.

#### Tick Handling

```elixir
def handle_info(:tick, state) do
  updated_symbols =
    Map.new(state.symbols, fn {symbol, symbol_data} ->
      {symbol, update_symbol_data(symbol_data)}
    end)

  updated_symbols
  |> Task.async_stream(fn {symbol, symbol_data} ->
    payload = %{
      symbol: symbol,
      value: symbol_data.current_value,
      timestamp: DateTime.utc_now()
    }
    routing_key = "stocks.#{symbol}"
    Logger.info("Generated #{symbol}: #{symbol_data.current_value}")
    Producer.Publisher.publish(routing_key, payload)
  end, max_concurrency: 10, timeout: 5000, on_timeout: :kill_task)
  |> Stream.run()

  schedule_tick(state.interval)
  {:noreply, %{state | symbols: updated_symbols}}
end
```

* Updates each symbol's data with `update_symbol_data/1`.
* Publishes updates concurrently using `Task.async_stream`.
* Reschedules next tick.

#### Price Calculation (`update_symbol_data/1`)

```elixir
defp update_symbol_data(symbol_data) do
  new_angle = symbol_data.angle + symbol_data.step

  new_base = symbol_data.base + symbol_data.drift_factor + (:rand.normal() * 0.05)

  sin_component = symbol_data.phase_mix * :math.sin(new_angle)
  cos_component = (1.0 - symbol_data.phase_mix) * :math.cos(new_angle)
  oscillation = symbol_data.amplitude * (sin_component + cos_component)

  noise = :rand.normal() * (symbol_data.amplitude / 20)

  new_value = new_base + oscillation + noise

  %{
    symbol_data
    | angle: new_angle,
      base: new_base,
      current_value: Float.round(new_value, 2)
  }
end
```

* Combines **base + drift**, **oscillation**, and **volatility noise**.
* Uses a quantum-inspired sine/cosine superposition to make movement less predictable.
* Updates symbol’s current value.

---

## 7. Price Generation Logic

The simulation produces realistic price streams using:

* **Base price + drift + Gaussian noise** → long-term trend
* **Superposition oscillation** → mid-term complex cycles
* **Volatility noise** → short-term unpredictability

**Formula:**

```
New Price = (Base Price + Drift + Light Noise) + (Complex Oscillation) + (Volatility Noise)
```

---

## 8. Key Features

* Real-time streaming of stock updates.
* Subscription-based filtering for each client.
* Resilient architecture that recovers from process failures.
* Market-inspired price generation balancing trends, oscillations, and randomness.
