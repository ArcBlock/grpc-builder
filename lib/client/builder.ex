defmodule GrpcBuilder.Client.Builder do
  @moduledoc """
  Macro for building RPC easily
  """
  alias GrpcBuilder.Client.Helper

  defmacro rpc(service, options, contents \\ []) do
    compile(service, options, contents)
  end

  # credo:disable-for-lines:55
  defp compile(service, options, contents) do
    {body, options} =
      cond do
        Keyword.has_key?(contents, :do) ->
          {contents[:do], options}

        Keyword.has_key?(options, :do) ->
          Keyword.pop(options, :do)

        true ->
          raise ArgumentError, message: "expected :do to be given as option"
      end

    mod = to_request_mod(service, Macro.to_string(options[:prefix]))

    quote bind_quoted: [
            mod: mod,
            service: service,
            options: options,
            body: Macro.escape(body, unquote: true)
          ] do
      default_opts = options[:opts] || []

      cond do
        options[:request_stream] == true ->
          def unquote(service)(reqs, name \\ "", opts \\ []) do
            conn = Helper.get_conn(name)
            reqs = Helper.to_req(reqs, unquote(mod))
            fun = fn var!(res) -> unquote(body) end
            opts = Keyword.merge(unquote(default_opts), opts)
            Helper.send_stream(unquote(service), conn, reqs, opts, fun)
          end

        options[:response_stream] == true and options[:no_params] == true ->
          def unquote(service)(name \\ "", opts \\ []) do
            conn = Helper.get_conn(name)
            req = apply(unquote(mod), :new, [])
            fun = fn var!(res) -> unquote(body) end
            opts = Keyword.merge(unquote(default_opts), opts)
            Helper.send(unquote(service), conn, req, opts, fun)
          end

        options[:response_stream] == true ->
          def unquote(service)(req, name \\ "", opts \\ []) do
            conn = Helper.get_conn(name)
            req = Helper.to_req(req, unquote(mod))
            fun = fn var!(res) -> unquote(body) end
            opts = Keyword.merge(unquote(default_opts), opts)
            Helper.send(unquote(service), conn, req, opts, fun)
          end

        options[:no_params] == true ->
          def unquote(service)(name \\ "", opts \\ []) do
            conn = Helper.get_conn(name)
            req = apply(unquote(mod), :new, [])
            fun = fn var!(res) -> unquote(body) end
            opts = Keyword.merge(unquote(default_opts), opts)
            Helper.send(unquote(service), conn, req, opts, fun)
          end

        true ->
          def unquote(service)(req, name \\ "", opts \\ []) do
            conn = Helper.get_conn(name)
            req = Helper.to_req(req, unquote(mod))
            fun = fn var!(res) -> unquote(body) end
            opts = Keyword.merge(unquote(default_opts), opts)
            Helper.send(unquote(service), conn, req, opts, fun)
          end
      end
    end
  end

  defp to_request_mod(service, prefix) do
    name =
      service
      |> Atom.to_string()
      |> Recase.to_pascal()

    Module.concat(prefix, "Request#{name}")
  end
end
