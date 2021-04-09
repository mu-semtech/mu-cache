defmodule MuElixirCache do
  @moduledoc """
  Main supervisor for the cache.
  """
  use Application

  def start(_type, _args) do
    IO.puts("Starting application")
    # List all child processes to be supervised
    children = [
      {Cache.Registry, %{}},
      {Plug.Cowboy,
       scheme: :http,
       plug: UsePlugProxy,
       options: [
         port: 80,
         protocol_options: [max_header_value_length: 409_600_000, max_keepalive: 1000]
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
