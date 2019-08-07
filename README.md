# GrpcBuilder

Generate GRPC client and server code.

## Installation

```elixir
def deps do
  [
    {:grpc_builder, "~> 0.1.0"}
  ]
end
```

## Usage

In your GRPC client SDK application code, add `GrpcBuilder.Client.ConnSupervisor` into the children:

```elixir
defmodule YourSdk.Application do
  @moduledoc false

  use Application
  alias GrpcBuilder.Client.ConnSupervisor

  def start(_type, _args) do
    children = [
      {ConnSupervisor, strategy: :one_for_one, name: ConnSupervisor}
    ]

    opts = [strategy: :one_for_one, name: YourSdk.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Add your RPC definitions like this:

```elixir
defmodule YourSdk.Rpc do
  @moduledoc """
  RPC client definition
  """
  import GrpcBuilder.Client.Builder, only: [rpc: 2, rpc: 3]

  # here the `res` is the response GRPC server returned to you. You can write code to process the response here.
  rpc :get_job, prefix: YourProtoAbi, do: res.job
end
```

You also need to define a Stub:

```elixir
defmodule GrpcBuilder.Client.Stub do
  use GrpcBuilder.Client.StubGen, services: %{
    get_job: YourProtoAbi.GrpcService.Stub
  }
end
```

That's it! Then you can use your SDK like this:

```elixir
GrpcBuilder.Client.connect("tcp://127.0.0.1:12345", name: "your_conn_name", default: true)
YourSdk.Rpc.get_job(request) # this is to use the default connection
YourSdk.Rpc.get_job(request, "your_conn_name") # this is the same as previous call
```
