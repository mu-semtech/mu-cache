defmodule UsePlugProxy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :mu_cache,
      version: "2.0.2",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def aliases do
    [server: "run --no-halt"]
  end

  # def aliases do
  #   [server: ["run", &UsePlugProxy.start/1]]
  # end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      extra_applications: [:logger, :cowboy, :plug_mint_proxy],
      mod: {MuElixirCache, []},
      env: []
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:plug_mint_proxy, git: "https://github.com/madnificent/plug-mint-proxy.git", branch: "feature/separate-example-runner"},
      {:plug, "~> 1.11.1"},
      {:plug_cowboy, "~> 2.4.1"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:poison, "~> 2.0"}
    ]
  end
end
