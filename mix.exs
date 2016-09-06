defmodule UsePlugProxy.Mixfile do
  use Mix.Project

  def project do
    [app: :use_plug_proxy,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     aliases: aliases]
  end

  def aliases do
    [server: ["run", &UsePlugProxy.start/1]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :cowboy, :plug, :plug_proxy]]
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
    [{:plug_proxy, git: "file:///home/madnificent/code/elixir/plug-proxy/"},
     {:poison, "~> 2.0"}]
  end
end
