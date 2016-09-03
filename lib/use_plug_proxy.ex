defmodule UsePlugProxy do
  use Plug.Router

  def start(_argv) do
    # port = 80
    port = 8888
    IO.puts "Starting Plug with Cowboy on port #{port}"
    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
    :timer.sleep(:infinity)
  end

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/google" do
    opts = PlugProxy.init( url: "https://duckduckgo.com" )
    PlugProxy.call( conn, opts )
  end

  get "/debug" do
    send_resp( conn, 200, "debugging is a go" )
  end
end
