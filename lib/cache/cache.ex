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
    state = state
    |> clear_keys!( clear_keys )
    |> cache_keys!( cache_keys, request_key )

    if cache_keys do
      cache = Map.put( state.cache, request_key, response )
      { :reply, :ok, Map.put( state, :cache, cache ) }
    else
      { :reply, :ok, state }
    end
  end

  defp has_key?( state, key ) do
    Map.has_key?( state.cache, key )
  end

  defp clear_keys!( state, clear_keys ) do
    Enum.reduce clear_keys, state, fn ( state, clear_key ) ->
      key_cache = state.caches_by_key
      if Map.has_key? key_cache, clear_key do
        request_keys = key_cache[clear_key]
        state = state
        |> clear_cache_by_key!( state )
        |> Map.put( :caches_by_key, Map.delete( key_cache, clear_key ) )
      else
        state
      end
    end
  end

  defp clear_cache_by_key!( state, request_key ) do
    key_cache = state.caches_by_key
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
    key_cache = Enum.reduce cache_keys, key_cache, fn( cache_key, key_cache ) ->
      if Map.has_key? key_cache, cache_key do
        current_list = Map.get key_cache, cache_key
        if Enum.member? current_list, request_key do
          # We are already in the list
          key_cache
        else
          # We have a list to append to
          Map.put key_cache, cache_key, [ request_key |  current_list ]
        end
      else
        # The cache key was unkown
        Map.put key_cache, cache_key, [request_key]
      end
    end
    %{ state | caches_by_key: key_cache }
  end
end
