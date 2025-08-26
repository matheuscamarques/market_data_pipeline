defmodule PhoenixWeb.RabbitMQForwarder do
  use GenServer
  require Logger
  alias Phoenix.PubSub

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Conecta ao RabbitMQ
    case connect() do
      {:ok, state} ->
        Logger.info("RabbitMQ Forwarder connected successfully")
        {:ok, state}

      {:error, error} ->
        Logger.error("Failed to connect to RabbitMQ: #{inspect(error)}")
        # Tenta reconectar após um delay
        Process.send_after(self(), :reconnect, 5000)
        {:ok, %{conn: nil, chan: nil}}
    end
  end

  defp connect do
    rabbitmq_url = System.get_env("RABBITMQ_URL") || "amqp://localhost:5672"

    case AMQP.Connection.open(rabbitmq_url) do
      {:ok, conn} ->
        Process.monitor(conn.pid)

        {:ok, chan} = AMQP.Channel.open(conn)

        # Declara o exchange (caso não exista)
        :ok = AMQP.Exchange.declare(chan, "stock_updates", :topic, durable: true)

        # Declara uma fila exclusiva para este consumidor
        {:ok, %{queue: queue_name}} = AMQP.Queue.declare(chan, "", exclusive: true)

        # Faz bind com todas as ações
        :ok = AMQP.Queue.bind(chan, queue_name, "stock_updates", routing_key: "stocks.#")

        # Começa a consumir mensagens
        {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queue_name, nil, no_ack: true)

        {:ok, %{conn: conn, chan: chan, queue_name: queue_name}}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def handle_info({:basic_deliver, payload, %{routing_key: routing_key}}, state) do
    # Extrai o símbolo da routing key (ex: "stocks.AAPL" -> "AAPL")
    symbol = String.replace(routing_key, "stocks.", "")

    case Jason.decode(payload) do
      {:ok, data} ->
        # Adiciona o símbolo aos dados
        data_with_symbol = Map.put(data, "symbol", symbol)

        # CORREÇÃO: Usando Phoenix.PubSub para broadcast
        topic = "stocks:#{symbol}"
        PubSub.broadcast(PhoenixWeb.PubSub, topic, {:new_tick, data_with_symbol})

        # Também publica em um tópico geral
        PubSub.broadcast(PhoenixWeb.PubSub, "stocks:all", {:new_tick, data_with_symbol})

      {:error, error} ->
        Logger.error("Failed to parse message: #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:reconnect, _state) do
    case connect() do
      {:ok, new_state} ->
        Logger.info("RabbitMQ Forwarder reconnected successfully")
        {:noreply, new_state}

      {:error, error} ->
        Logger.error("Failed to reconnect to RabbitMQ: #{inspect(error)}")
        Process.send_after(self(), :reconnect, 5000)
        {:noreply, %{conn: nil, chan: nil}}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{conn: %{pid: conn_pid}} = state)
      when pid == conn_pid do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}. Attempting to reconnect...")
    Process.send_after(self(), :reconnect, 5000)
    {:noreply, %{state | conn: nil, chan: nil}}
  end

  @impl true
  def handle_info(_info, state) do
    {:noreply, state}
  end
end
