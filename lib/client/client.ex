defmodule GrpcBuilder.Client do
  @moduledoc """
  public interface for GrpcBuilder client
  """
  alias GrpcBuilder.Client.ConnSupervisor

  @doc """
  Upon initialization, SDK can call this function to make a gRPC connection to gRPC service.
  """
  @spec connect(String.t(), Keyword.t()) ::
          :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def connect(host, opts) do
    name = String.to_atom(opts[:name])

    case opts[:default] do
      true -> Application.put_env(:grpc_builder, :default_conn, name)
      _ -> nil
    end

    ConnSupervisor.add(name, host)
  end
end
