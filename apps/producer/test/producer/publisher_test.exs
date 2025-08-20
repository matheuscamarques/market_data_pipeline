defmodule Producer.PublisherTest do
  use ExUnit.Case
  alias Producer.Publisher

  test "GenServer está vivo e processa publish" do
    # Verifica se o GenServer já está rodando
    pid =
      case Process.whereis(Publisher) do
        nil ->
          # Se não existe, inicia normalmente
          {:ok, pid} = Publisher.start_link([])
          pid

        existing_pid ->
          existing_pid
      end

    assert Process.alive?(pid)

    # Cria payload de teste
    payload = %{symbol: "AAPL", value: 123, timestamp: ~U[2025-08-20 00:00:00Z]}

    # Envia publish
    Publisher.publish("stocks.AAPL", payload)

    # Pequena pausa para garantir que o GenServer processe a mensagem
    Process.sleep(100)

    # Garante que o processo continua vivo
    assert Process.alive?(pid)
  end
end
