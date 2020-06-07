defmodule UsePlugProxy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :use_plug_proxy,
      version: "2.0.1",
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
      extra_applications: [:logger, :httpoison, :poison, :plug, :cowboy],
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
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:httpoison, "~> 1.1"},
      {:plug_proxy, git: "https://github.com/madnificent/plug-proxy.git"},
      {:plug_cowboy, "~> 1.0"},
      {:poison, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"}
    ]
  end
end
