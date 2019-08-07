defmodule GrpcBuilder.Client.Conn do
  @moduledoc """
  Wrapper for gRPC connection
  """
  use TypedStruct
  alias GRPC.Channel

  typedstruct do
    field(:name, String.t())
    field(:endpoint, String.t())
    field(:chan, Channel.t() | nil, default: nil)
    field(:chain_id, String.t(), default: "")
    field(:decimal, non_neg_integer())
    field(:gas, map(), default: %{})
  end
end

defmodule GrpcBuilder.Client.RpcConn do
  @moduledoc """
  Persistent gRPC connection to GRPC server.
  """
  use Connection

  require Logger

  alias GrpcBuilder.Client.Conn

  alias GRPC.Stub, as: Client

  # ------------------------------------------------------------------
  # api
  # ------------------------------------------------------------------

  @doc """
  The parameters for start_link/3 are:

  * `endpoint` - the address of gRPC server in `host:port` format
  * `opts` - the options for gRPC http2 client `gun`
  * `callback` - the 0 arity function to be called when gRPC connection is established
  """
  @spec start_link(atom(), String.t(), Keyword.t(), (() -> any) | nil) :: GenServer.on_start()
  def start_link(name, endpoint, opts, callback) do
    Connection.start_link(__MODULE__, {endpoint, name, opts, callback}, name: name)
  end

  @spec get_conn(atom()) :: Conn.t() | {:error, :closed}
  def get_conn(name) do
    Connection.call(name, :get_conn)
  end

  @spec close(atom()) :: any()
  def close(name), do: Connection.call(name, :close)

  # ------------------------------------------------------------------
  # callbacks
  # ------------------------------------------------------------------

  def init({"unix://" <> endpoint, name, opts, callback}),
    do:
      {:connect, :init,
       %{opts: opts, callback: callback, config: %{}, conn: %Conn{name: name, endpoint: endpoint}}}

  def init({"tcp://" <> endpoint, name, opts, callback}),
    do:
      {:connect, :init,
       %{opts: opts, callback: callback, config: %{}, conn: %Conn{name: name, endpoint: endpoint}}}

  def connect(
        _,
        %{conn: %{chan: nil, endpoint: endpoint} = conn, opts: opts, callback: callback} = state
      ) do
    Logger.info("GRPC: reconnect to #{endpoint}...")

    case Client.connect(endpoint, opts) do
      {:ok, chan} ->
        Process.monitor(chan.adapter_payload.conn_pid)
        # send(self(), :get_config)
        callback && spawn(fn -> callback.(conn.name) end)
        {:ok, %{state | conn: %{conn | chan: chan}}}

      {:error, _} ->
        {:backoff, 5000, state}
    end
  end

  def disconnect(info, %{conn: %{chan: chan} = conn} = state) do
    {:ok, _} = Client.disconnect(chan)

    case info do
      {:close, from} -> Connection.reply(from, :ok)
      {:error, :closed} -> Logger.error("GRPC connection closed")
      {:error, reason} -> Logger.error("GRPC connection error: #{inspect(reason)}")
    end

    {:connect, :reconnect, %{state | conn: %{conn | chan: nil}}}
  end

  # call

  def handle_call(_, _, %{chan: nil} = state) do
    {:reply, {:error, :closed}, state}
  end

  def handle_call(:get_conn, _from, %{conn: conn} = state) do
    {:reply, conn, state}
  end

  def handle_call(:close, from, state) do
    {:disconnect, {:close, from}, state}
  end

  # info

  def handle_info(
        {:DOWN, _ref, :process, pid, reason},
        %{conn: %{chan: %{adapter_payload: %{conn_pid: pid}}} = conn} = state
      ) do
    Logger.debug("GRPC: connection down with reason #{inspect(reason)}...")
    {:connect, :reconnect, %{state | conn: %{conn | chan: nil}}}
  end

  def handle_info(msg, state) do
    Logger.debug("Got unexpected info message: #{inspect(msg)}")
    {:noreply, state}
  end
end
