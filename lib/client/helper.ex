defmodule GrpcBuilder.Client.Helper do
  @moduledoc false

  require Logger
  alias GRPC.Stub, as: Client
  alias GrpcBuilder.Client.RpcConn

  @recv_timeout 10_000
  @deadline_expired 4

  @doc """
  Get the gRPC connection channel.
  """
  @spec get_conn(atom(), String.t() | atom()) :: Conn.t()
  def get_conn(rpc_app, name \\ "")

  def get_conn(rpc_app, ""), do: get_conn(rpc_app, Application.get_env(rpc_app, :default_conn))

  def get_conn(rpc_app, name) when is_binary(name),
    do: get_conn(rpc_app, String.to_existing_atom(name))

  def get_conn(_rpc_app, name), do: RpcConn.get_conn(name)

  @doc """
  Send a single request to GRPC server.
  """
  def send(rpc_app, service, conn, req, opts, fun) do
    mod = get_stub_mod(rpc_app)
    grpc_opts = get_grpc_opts(opts)
    data = apply(mod, service, [conn.chan, req, grpc_opts])

    case data do
      {:ok, res} ->
        process_response(req, res, opts, fun)

      {:error, msg} ->
        Logger.warn(
          "Failed to process request for #{inspect(service)}. Error: #{inspect(msg)}, Req is #{
            inspect(req)
          }. "
        )

        {:error, :internal}
    end
  end

  @doc """
  Send multiple requests to GRPC server one by one.
  """
  def send_stream(rpc_app, service, conn, reqs, opts, fun) when is_list(reqs) do
    stream = get_stream(rpc_app, service, conn, opts)
    do_send_stream(stream, reqs, opts, fun)
  end

  def send_stream(rpc_app, service, conn, req, opts, fun) do
    stream = get_stream(rpc_app, service, conn, opts)

    stream
    |> do_send_stream([req], opts, fun)
    |> case do
      [res] -> res
      res -> res
    end
  end

  @doc """
  Support different ways to pass parameters to rpc.

      * %RequestFunction{k1: v1, k2: v2}
      * [k1: v1, k2: v2]
      * [%RequestFunction{k1: v1, k2: v2}, ...]
      * [[k1: v1, k2: v2], ...]
  """
  def to_req(%{__struct__: mod} = req, mod), do: req
  def to_req([{_k, _v} | _] = req, mod), do: mod.new(req)
  def to_req(reqs, mod), do: Enum.map(reqs, &to_req(&1, mod))

  # private function
  defp get_stub_mod(rpc_app),
    do: rpc_app |> Atom.to_string() |> Recase.to_pascal() |> Module.concat("Client.Stub")

  defp get_stream(rpc_app, service, conn, opts),
    do: apply(get_stub_mod(rpc_app), service, [conn.chan, opts])

  defp recv(req, stream, opts, fun) do
    case Client.recv(stream, timeout: @recv_timeout) do
      {:ok, res} ->
        process_response(req, res, opts, fun)

      {:error, msg} ->
        Logger.warn(
          "Failed to process request for stream #{inspect(stream)}.  Error: #{inspect(msg)}"
        )

        {:error, :internal}
    end
  end

  defp process_response(req, %{code: :ok} = res, _opts, fun) do
    data = Map.from_struct(res)

    fun.(Map.put(data, :req, req))
  end

  defp process_response(_req, %{code: code}, _opts, _fun), do: {:error, code}

  defp process_response(req, res_stream, opts, fun) do
    mod = if opts[:stream_mode] == true, do: Stream, else: Enum

    mod.map(res_stream, fn
      {:ok, res} ->
        process_response(req, res, opts, fun)

      {:error, %{status: @deadline_expired}} ->
        Logger.warn("Deadline expired for the stream.")
        process_response(req, %{code: :timeout}, opts, fun)

      {:error, msg} ->
        Logger.warn("Failed to process response.  Error: #{inspect(msg)}")
        {:error, :internal}
    end)
  end

  defp do_send_stream(stream, [req], opts, fun) do
    Client.send_request(stream, req, end_stream: true)
    recv(req, stream, opts, fun)
  end

  defp do_send_stream(stream, [req | rest], opts, fun) do
    Client.send_request(stream, req, end_stream: false)
    do_send_stream(stream, rest, opts, fun)
  end

  defp get_grpc_opts(opts) do
    Keyword.delete(opts, :stream_mode)
  end
end
