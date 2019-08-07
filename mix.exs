defmodule GrpcBuilder.MixProject do
  use Mix.Project

  @top File.cwd!()

  @version @top |> Path.join("version") |> File.read!() |> String.trim()
  @elixir_version @top |> Path.join(".elixir_version") |> File.read!() |> String.trim()

  def project do
    [
      app: :grpc_builder,
      version: @version,
      elixir: @elixir_version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      defaultdialyzer: [ignore_warnings: ".dialyzer_ignore.exs", plt_add_apps: []],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      description: description(),
      package: package(),
      # Docs
      name: "GrpcBuilder",
      source_url: "https://github.com/arcblock/grpc-builder",
      homepage_url: "https://github.com/arcblock/grpc-builder",
      docs: [
        main: "GrpcBuilder",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:connection, "~> 1.0"},
      {:grpc, "~> 0.4.0-alpha.2"},
      {:recase, "~> 0.4"},
      {:typed_struct, "~> 0.1.4"},

      # dev and test
      {:credo, "~> 1.1", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.11", only: [:test]},
      {:pre_commit_hook, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    GRPC builder helps to generate the GRPC client and server code.
    """
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        "README*",
        "LICENSE",
        "version",
        ".elixir_version"
      ],
      licenses: ["Apache 2.0"],
      maintainers: [
        "tyr.chen@gmail.com"
      ],
      links: %{
        "GitHub" => "https://github.com/arcblock/grpc-builder",
        "Docs" => "https://hexdocs.pm/grpc-builder"
      }
    ]
  end
end
