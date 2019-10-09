defmodule GrpcBuilder.Client.SupervisorGen do
  @moduledoc """
  Supervise the connections.
  """
  defmacro __using__(opts) do
    mod = opts[:mod]

    quote bind_quoted: [mod: mod] do
      use DynamicSupervisor
      alias GrpcBuilder.Client.RpcConn

      def start_link(_arg) do
        DynamicSupervisor.start_link(unquote(mod), [], name: __MODULE__)
      end

      def init([]) do
        DynamicSupervisor.init(strategy: :one_for_one)
      end

      def add(name, addr, callback \\ nil) do
        child_spec = %{
          id: name,
          # disable retry on gun's part to prevent undesired zombie connections
          start: {RpcConn, :start_link, [name, addr, [adapter_opts: %{retry: 0}], callback]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }

        DynamicSupervisor.start_child(unquote(mod), child_spec)
      end

      def remove(pid) do
        DynamicSupervisor.terminate_child(unquote(mod), pid)
      end

      def children do
        DynamicSupervisor.which_children(unquote(mod))
      end

      def get_names do
        Enum.map(children(), fn {_, p, _, _} -> p |> Process.info(:registered_name) |> elem(1) end)
      end

      def count_children do
        DynamicSupervisor.count_children(unquote(mod))
      end
    end
  end
end
