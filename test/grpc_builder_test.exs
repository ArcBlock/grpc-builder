defmodule GrpcBuilderTest do
  use ExUnit.Case
  doctest GrpcBuilder

  test "greets the world" do
    assert GrpcBuilder.hello() == :world
  end
end
