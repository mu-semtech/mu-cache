defmodule UsePlugProxy.Cache do
  use GenServer

  def find_cache( method, location ) do
    case GenServer.call( __MODULE__, { :find_cache, method, location } ) do
      { :ok, response } -> response
      { :not_found } -> nil
    end
  end

  def store( method, location, response ) do
    GenServer.call( __MODULE__, {:store, method, location, response } )
  end

  ###
  # GenServer API
  ###
  def start_link() do
    GenServer.start_link( __MODULE__, [%{cache: %{}, caches_by_key: %{}}], name: __MODULE__ )
  end

  def init(_) do
    {:ok, %{cache: %{}, caches_by_key: %{}}}
  end


  def handle_call({:has_key, method, location}, _from, state) do
    { :reply, has_key?( state, {method, location} ), state }
  end

  def handle_call({:find_cache, method, location}, _from, state) do
    if has_key? state, {method, location} do
      { :reply, { :ok, Map.get( state.cache, { method, location} ) }, state }
    else
      { :reply, { :not_found }, state }
    end
  end

  def handle_call({:store, method, location, response}, _from, state) do
    request_key = { method, location }
    %{ cache_keys: cache_keys, clear_keys: clear_keys } = response

    # IO.inspect { :cache_keys, cache_keys }
    # IO.inspect { :clear_keys, clear_keys }

    state = state
    |> clear_keys!( clear_keys )
    |> cache_keys!( cache_keys, request_key )

    if cache_keys != [] do
      cache = Map.put( state.cache, request_key, response )
      state = Map.put( state, :cache, cache )
      # IO.puts "Resulting state:"
      # IO.inspect( state )
      { :reply, :ok, state }
    else
      # IO.puts "Resulting state:"
      # IO.inspect( state )
      { :reply, :ok, state }
    end
  end

  defp has_key?( state, key ) do
    Map.has_key?( state.cache, key )
  end

  defp clear_keys!( state, clear_keys ) do
    # IO.puts "Clearing keys: "
    # IO.inspect clear_keys
    Enum.reduce clear_keys, state, fn ( clear_key, state ) ->
      # IO.puts "Clearing one key:"
      # IO.inspect clear_key
      key_cache = state.caches_by_key
      # IO.puts "Caches by key:"
      # IO.inspect key_cache
      if Map.has_key? key_cache, clear_key do
        request_keys = key_cache[clear_key]
        state = Enum.reduce( request_keys, state, &(clear_cache_by_key! &2, &1) ) # something goes wrong here
        |> Map.put( :caches_by_key, Map.delete( key_cache, clear_key ) )
      else
        state
      end
    end
  end

  defp clear_cache_by_key!( state, request_key ) do
    key_cache = state.caches_by_key
    # IO.puts "Clearing cache by key"
    # IO.inspect {:request_key, request_key}
    # IO.inspect {:cache, state.cache}
    request_object = state.cache[request_key]
    %{ cache_keys: cache_keys } = request_object

    # Remove the cached references
    cache = Map.delete( state.cache, request_key )
    key_cache = Enum.reduce cache_keys, key_cache, fn (cache_key, key_cache) ->
      list = Map.get( key_cache, cache_key, [] )
      Map.put( key_cache, cache_key, List.delete( list, cache_key ) )
    end
    
    %{ state | cache: cache, caches_by_key: key_cache }
  end

  defp cache_keys!( state, cache_keys, request_key ) do
    key_cache = state.caches_by_key
    # IO.puts "key_cache:"
    # IO.inspect key_cache
    # IO.puts "Caching key:"
    # IO.inspect cache_keys
    # IO.puts "Request key:"
    # IO.inspect request_key
    key_cache = Enum.reduce cache_keys, key_cache, fn( cache_key, key_cache ) ->
      if Map.has_key? key_cache, cache_key do
        current_list = Map.get key_cache, cache_key
        if Enum.member? current_list, request_key do
          # We are already in the list
          # IO.puts "Don't cache key duplicate:"
          # IO.inspect cache_key
          # IO.inspect current_list
          key_cache
        else
          # We have a list to append to
          # IO.puts "Append cache key to list:"
          # IO.inspect cache_key
          # IO.inspect current_list
          Map.put key_cache, cache_key, [ request_key |  current_list ]
        end
      else
        # The cache key was unkown
          # IO.puts "Create new cache list:"
          # IO.inspect cache_key
        Map.put key_cache, cache_key, [request_key]
      end
    end
    %{ state | caches_by_key: key_cache }
  end
end
