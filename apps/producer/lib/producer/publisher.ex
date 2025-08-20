defmodule Producer.Publisher do
  use GenServer
  require Logger

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def publish(routing_key, payload) do
    GenServer.cast(__MODULE__, {:publish, routing_key, payload})
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    state = connect()
    {:ok, state}
  end

  @impl true
  def handle_cast({:publish, routing_key, payload}, %{chan: chan} = state) do
    json_payload = Jason.encode!(payload)

    :ok = AMQP.Basic.publish(
      chan,
      "stock_updates",
      routing_key,
      json_payload,
      persistent: true
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
    Logger.error("RabbitMQ connection lost: #{inspect(reason)}. Reconnecting...")
    {:noreply, connect()}
  end

  def handle_info(_, state), do: {:noreply, state}

  # --- Private helpers ---

  defp connect do
    rabbitmq_url =
      Application.fetch_env!(:producer, Producer.Publisher)
      |> Keyword.fetch!(:rabbitmq_url)

    case AMQP.Connection.open(rabbitmq_url) do
      {:ok, conn} ->
        # Monitora o processo da conexão para detectar falhas
        Process.monitor(conn.pid)

        {:ok, chan} = AMQP.Channel.open(conn)
        AMQP.Confirm.select(chan)

        :ok = AMQP.Exchange.declare(
          chan,
          "stock_updates",
          :topic,
          durable: true
        )

        %{conn: conn, chan: chan}

      {:error, reason} ->
        Logger.error("Failed to connect to RabbitMQ (#{inspect(reason)}). Retrying...")
        Process.sleep(5000)
        connect()
    end
  end
end
