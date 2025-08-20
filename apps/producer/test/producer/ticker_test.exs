defmodule Producer.TickerTest do
  use ExUnit.Case
  alias Producer.Ticker

  test "GenServer updates state on tick" do
    pid =
      case Process.whereis(Ticker) do
        nil ->
          {:ok, pid} = Ticker.start_link(symbols: ["TEST"], interval: 10)
          pid

        existing_pid ->
          existing_pid
      end

    initial_state = :sys.get_state(pid)
    initial_angle = initial_state.angle

    Process.sleep(1000)

    new_state = :sys.get_state(pid)
    new_angle = new_state.angle

    assert new_angle != initial_angle

    assert Process.alive?(pid)
  end
end
