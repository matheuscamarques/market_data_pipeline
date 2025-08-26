defmodule PhoenixWebWeb.StockTickerLive do
  use PhoenixWebWeb, :live_view
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    # Estado inicial
    initial_state = %{
      active_symbol: "AAPL",
      symbols_data: %{
        "AAPL" => %{value: "N/A", timestamp: nil, history: []}
      },
      subscribed_symbols: MapSet.new(["AAPL"])
    }

    socket = assign(socket, initial_state)

    if connected?(socket) do
      # Inscreve nos tópicos iniciais via Phoenix.PubSub
      initial_state.subscribed_symbols
      |> Enum.each(&subscribe_to_symbol/1)

      # Inscreve no tópico geral para receber todas as atualizações
      # PubSub.subscribe(PhoenixWeb.PubSub, "stocks:all")
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("subscribe", %{"symbol" => symbol}, socket) when is_binary(symbol) do
    symbol = String.trim(symbol) |> String.upcase()

    if symbol != "" do
      # Adiciona o símbolo aos monitorados se não existir
      subscribed_symbols =
        if MapSet.member?(socket.assigns.subscribed_symbols, symbol) do
          socket.assigns.subscribed_symbols
        else
          subscribe_to_symbol(symbol)
          MapSet.put(socket.assigns.subscribed_symbols, symbol)
        end

      # Inicializa dados do símbolo se não existirem
      symbols_data =
        if Map.has_key?(socket.assigns.symbols_data, symbol) do
          socket.assigns.symbols_data
        else
          Map.put(socket.assigns.symbols_data, symbol, %{
            value: "N/A",
            timestamp: nil,
            history: []
          })
        end

      {:noreply,
       socket
       |> assign(
         active_symbol: symbol,
         symbols_data: symbols_data,
         subscribed_symbols: subscribed_symbols
       )
       |> push_event("focus-input", %{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_watchlist", %{"symbol" => symbol}, socket) when is_binary(symbol) do
    symbol = String.trim(symbol) |> String.upcase()

    if symbol != "" and not MapSet.member?(socket.assigns.subscribed_symbols, symbol) do
      subscribe_to_symbol(symbol)

      # Inicializa dados do novo símbolo
      new_symbols_data =
        Map.put(socket.assigns.symbols_data, symbol, %{
          value: "N/A",
          timestamp: nil,
          history: []
        })

      {:noreply,
       socket
       |> update(:subscribed_symbols, &MapSet.put(&1, symbol))
       |> assign(symbols_data: new_symbols_data)
       |> push_event("focus-input", %{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_watchlist", %{"symbol" => symbol}, socket) do
    if symbol != socket.assigns.active_symbol do
      unsubscribe_from_symbol(symbol)

      {:noreply,
       socket
       |> update(:subscribed_symbols, &MapSet.delete(&1, symbol))
       |> update(:symbols_data, &Map.delete(&1, symbol))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_active", %{"symbol" => symbol}, socket) do
    # Atualiza o gráfico quando o símbolo ativo muda
    if data = socket.assigns.symbols_data[symbol] do
      chart_data = prepare_chart_data(data.history)

      socket =
        socket
        |> assign(active_symbol: symbol)
        # CORREÇÃO: Envia o símbolo junto com os dados para atualizar o label do gráfico
        |> push_event("update_chart", %{data: chart_data, symbol: symbol})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_tick, data}, socket) do
    symbol = data["symbol"]
    value = Float.round(data["value"], 2)
    timestamp = data["timestamp"]

    # Atualiza os dados do símbolo específico
    updated_symbols_data =
      case Map.get(socket.assigns.symbols_data, symbol) do
        nil ->
          # Novo símbolo - inicializa com dados
          Map.put(socket.assigns.symbols_data, symbol, %{
            value: value,
            timestamp: timestamp,
            history: [%{value: value, timestamp: timestamp}]
          })

        symbol_data ->
          # Atualiza símbolo existente
          new_history = [
            %{value: value, timestamp: timestamp}
            # Mantém apenas as últimas 200 entradas
            | Enum.take(symbol_data.history, 199)
          ]

          updated_data = %{
            value: value,
            timestamp: timestamp,
            history: new_history
          }

          Map.put(socket.assigns.symbols_data, symbol, updated_data)
      end

    socket = assign(socket, symbols_data: updated_symbols_data)

    # Se o tick for do símbolo ativo, envia o evento para atualizar o gráfico detalhado
    if symbol == socket.assigns.active_symbol do
      history = updated_symbols_data[symbol].history
      chart_data = prepare_chart_data(history)

      # CORREÇÃO: Envia o evento com os dados e o símbolo
      socket = push_event(socket, "update_chart", %{data: chart_data, symbol: symbol})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp subscribe_to_symbol(symbol) do
    topic = "stocks:#{symbol}"
    PubSub.subscribe(PhoenixWeb.PubSub, topic)
  end

  defp unsubscribe_from_symbol(symbol) do
    topic = "stocks:#{symbol}"
    PubSub.unsubscribe(PhoenixWeb.PubSub, topic)
  end

  # Prepara dados para o gráfico
  defp prepare_chart_data(history) do
    Enum.map(history, fn %{value: value, timestamp: timestamp} ->
      %{
        x: timestamp,
        y: value
      }
    end)
    # Ordena do mais antigo para o mais recente
    |> Enum.reverse()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold text-center mb-8">Live Stock Ticker</h1>

    <!-- Formulário de adição de símbolos -->
        <div class="bg-white rounded-lg shadow p-6 mb-6">
          <h2 class="text-xl font-semibold mb-4">Manage Stocks</h2>
          <form phx-submit="add_watchlist" class="flex items-center">
            <input
              type="text"
              name="symbol"
              placeholder="Add stock symbol (e.g., AAPL, GOOGL, MSFT)"
              class="flex-grow px-4 py-2 border rounded-l focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button
              type="submit"
              class="px-4 py-2 bg-green-500 text-white rounded-r hover:bg-green-600 focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              Add to Watchlist
            </button>
          </form>
        </div>

    <!-- Grid com todos os símbolos monitorados -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-8">
          <%= for symbol <- @subscribed_symbols do %>
            <%= if symbol_data = @symbols_data[symbol] do %>
              <div
                class={"bg-white rounded-lg shadow p-4 cursor-pointer transition-all duration-200 " <>
                      if symbol == @active_symbol, do: "ring-2 ring-blue-500", else: "hover:shadow-md"}
                phx-click="set_active"
                phx-value-symbol={symbol}
              >
                <div class="flex justify-between items-start mb-2">
                  <h3 class="text-lg font-bold text-blue-600">{symbol}</h3>
                  <%= if symbol != @active_symbol do %>
                    <button
                      phx-click="remove_watchlist"
                      phx-value-symbol={symbol}
                      class="text-red-400 hover:text-red-600 text-sm"
                      title="Remove from watchlist"
                    >
                      &#x2715;
                    </button>
                  <% end %>
                </div>

                <div class="text-2xl font-bold mb-1">
                  {symbol_data.value}
                </div>

                <div class="text-xs text-gray-500">
                  <%= if symbol_data.timestamp do %>
                    Updated: {DateTime.from_iso8601(symbol_data.timestamp)
                    |> elem(1)
                    |> Calendar.strftime("%H:%M:%S")}
                  <% else %>
                    No data yet
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

    <!-- Detalhes do símbolo ativo -->
        <%= if active_data = @symbols_data[@active_symbol] do %>
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-blue-600">{@active_symbol}</h2>
              <div class="text-sm text-gray-500">
                <%= if active_data.timestamp do %>
                  Last update: {DateTime.from_iso8601(active_data.timestamp)
                  |> elem(1)
                  |> Calendar.strftime("%H:%M:%S")}
                <% else %>
                  No data yet
                <% end %>
              </div>
            </div>

            <div class="text-4xl font-bold text-center mb-8">
              {active_data.value}
            </div>

    <!-- Gráfico detalhado -->
            <div class="mt-6 h-96">
              <canvas
                id="detailed-chart"
                phx-hook="Chart"
                phx-update="ignore"
                data-symbol={@active_symbol}
              >
              </canvas>
            </div>

    <!-- Histórico recente -->
            <div class="mt-6">
              <h3 class="text-lg font-semibold mb-3">Recent History</h3>
              <div class="max-h-40 overflow-y-auto">
                <table class="w-full text-sm">
                  <thead>
                    <tr class="text-left text-gray-500">
                      <th class="p-2">Time</th>
                      <th class="p-2">Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for %{value: value, timestamp: timestamp} <- Enum.take(active_data.history, 10) do %>
                      <tr class="border-t">
                        <td class="p-2">
                          {DateTime.from_iso8601(timestamp)
                          |> elem(1)
                          |> Calendar.strftime("%H:%M:%S")}
                        </td>
                        <td class="p-2 font-mono">{value}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
