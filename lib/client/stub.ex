defmodule GrpcBuilder.Client.StubGen do
  @moduledoc """
  Aggregate all RPCs
  """
  defmacro __using__(opts) do
    gen(opts)
  end

  defp gen(args) do
    quote bind_quoted: [args: args] do
      Enum.each(args[:services], fn {name, mod} ->
        def unquote(name)(chan, req, opts \\ []),
          do: apply(unquote(mod), unquote(name), [chan, req, opts])
      end)
    end
  end
end
