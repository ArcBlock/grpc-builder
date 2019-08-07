defmodule GrpcBuilder.Client.Stub do
  @moduledoc """
  Aggregate all RPCs
  """
  def gen(services) do
    Enum.each(services, fn {name, mod} ->
      quote do
        defdelegate unquote(name)(chan, req, opts \\ []), to: unquote(mod)
      end
    end)
  end
end
