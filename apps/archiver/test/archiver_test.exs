defmodule ArchiverTest do
  use ExUnit.Case
  doctest Archiver

  test "greets the world" do
    assert Archiver.hello() == :world
  end
end
