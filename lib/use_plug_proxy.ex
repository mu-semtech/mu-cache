defmodule UsePlugProxy do
  use Plug.Router

  alias UsePlugProxy.Cache

  def start(argv) do
    port = 80
    # port = 8888
    IO.puts "Starting Plug with Cowboy on port #{port}"
    Plug.Adapters.Cowboy.http __MODULE__, [], port: port
    UsePlugProxy.Cache.start_link()
    unless argv == :continue do
      :timer.sleep(:infinity)
    end
  end

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/cachecanhasresponse" do
    send_resp( conn, 200, "debugging is a go" )
  end

  match "/*path" do
    full_path = Enum.reduce( path, "", fn (a, b) -> a <> "/" <> b end )
    opts = PlugProxy.init url: "http://backend/" <> full_path
    cache = Cache.find_cache( conn.method, full_path )

    if cache do
      IO.puts "CACHE HIT!"
      merge_resp_headers( conn, cache.headers )
      |> send_resp( conn, 200, cache.body )
    else
      IO.puts "CACHE MISS!"
      processors = %{ header_processor: fn (headers, state) ->
                      # IO.puts "Received header:"
                      # IO.inspect headers
                      { headers, cache_keys } = extract_json_header( headers, "Cache-Keys" )
                      { headers, clear_keys } = extract_json_header( headers, "Clear-Keys" )
                      { headers, %{ state |
                                    headers: headers,
                                    cache_keys: cache_keys,
                                    clear_keys: clear_keys } }
                    end,
                      chunk_processor: fn (chunk, state) ->
                        # IO.puts "Received chunk:"
                        # IO.inspect chunk
                        { chunk, %{ state | body: state.body <> chunk } }
                      end,
                      body_processor: fn (body, state) ->
                        # IO.puts "Received body:"
                        # IO.inspect body
                        { body, %{ state | body: state.body <> body } }
                      end,
                      finish_hook: fn (state) ->
                        # IO.puts "Fully received body"
                        # IO.puts state.body
                        # IO.puts "Current state:"
                        # IO.inspect state
                        Cache.store( conn.method, full_path, state )
                        { true, state }
                      end,
                      state: %{is_processor_state: true, body: "", headers: %{}, status_code: 200, cache_keys: [], clear_keys: []}
                    }
      conn
      |> Map.put( :processors, processors )
      |> PlugProxy.call( opts )
      # |> IO.inspect
    end
  end

  defp extract_json_header( headers, header_name ) do
    case List.keyfind( headers, header_name, 0 ) do
      { ^header_name, keys } ->
        new_headers = List.keydelete( headers, header_name, 0 )

        { new_headers, Poison.decode!(keys) }
      _ ->
        { headers, [] }
    end
  end
end
