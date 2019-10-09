defmodule GrpcBuilder.Client.Gen do
  @moduledoc """
  public interface for GrpcBuilder client
  """
  defmacro __using__(opts) do
    mod = opts[:mod]
    app = opts[:app]

    quote bind_quoted: [mod: mod, app: app] do
      @doc """
      Upon initialization, SDK can call this function to make a gRPC connection to gRPC service.
      """
      @spec connect(String.t(), Keyword.t()) ::
              :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
      def connect(host, opts) do
        name = String.to_atom(opts[:name])

        case opts[:default] do
          true -> Application.put_env(unquote(app), :default_conn, name)
          _ -> nil
        end

        apply(unquote(mod), :add, [name, host])
      end
    end
  end
end
