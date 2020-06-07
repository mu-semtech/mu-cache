defmodule UsePlugProxy.Cache do
  use GenServer

  def find_cache( { _method, _full_path, _get_params, _allowed_groups } = key ) do
    case GenServer.call( __MODULE__, { :find_cache, key } ) do
      { :ok, response } -> response
      { :not_found } -> nil
    end
  end

  def store( { _method, _full_path, _get_params, _allowed_groups } = key, response ) do
    # IO.puts "Going to store new content"
    # IO.inspect( key, label: "Key to store under" )
    # IO.inspect( response, label: "Response to save" )
    GenServer.call( __MODULE__, {:store, key, response } )
  end

  def clear_keys( keys ) do
    GenServer.call( __MODULE__, {:clear_keys, keys} )
  end

  ###
  # GenServer API
  ###
  def start_link(_) do
    GenServer.start_link( __MODULE__, [%{cache: %{}, caches_by_key: %{}}], name: __MODULE__ )
  end

  def init(_) do
    {:ok, %{cache: %{}, caches_by_key: %{}}}
  end

  def handle_call({:find_cache, key}, _from, state) do
    if has_key? state, key do
      { :reply, { :ok, Map.get( state.cache, key ) }, state }
    else
      { :reply, { :not_found }, state }
    end
  end

  def handle_call({:store, request_key, response}, _from, state) do
    # IO.inspect( request_key, label: "Request key" )
    # IO.inspect( response, label: "Response" )

    %{ cache_keys: cache_keys, clear_keys: clear_keys } = response

    # IO.inspect { :cache_keys, cache_keys }
    # IO.inspect { :clear_keys, clear_keys }

    state =
      state
      # update state for clear_keys
      |> clear_keys!( clear_keys )

    # IO.puts "Executed clear keys"

    if cache_keys == [] do
      {:reply, :ok, state }
    else
      # IO.puts "Caching request"
      # update state for new cache
      state =
        state
        |> add_cache_key_dependency!( cache_keys, request_key )
        |> add_cached_value!( request_key, response )

      {:reply, :ok, state }
    end
  end

  def handle_call({:clear_keys, keys}, _from, state) do
    {:reply, :ok, clear_keys!( state, keys )}
  end

  defp has_key?( state, key ) do
    Map.has_key?( state.cache, key )
  end

  defp clear_keys!( state, [] ) do
    state
  end
  defp clear_keys!( state, clear_keys ) do
    # We have multiple clear_keys and need to update the state for it.
    %{ cache: cache, caches_by_key: caches_by_key } = state
    clear_urls = Enum.flat_map(clear_keys, &Map.get(caches_by_key, &1, []))

    cache = Map.drop( cache, clear_urls )
    caches_by_key = Map.drop(caches_by_key, clear_keys)

    Introspection.Informing.store_cleared_urls( clear_urls )

    %{ state |
       cache: cache,
       caches_by_key: caches_by_key }
  end

  defp add_cache_key_dependency!( state, [], _request_key ) do
    state
  end
  defp add_cache_key_dependency!( state, cache_keys, request_key ) do
    # For each cache_key, we need to see if the request_key is already
    # in the cache_keys and add it if it is not there.
    %{ caches_by_key: caches_by_key } = state

    caches_by_key =
      Enum.reduce( cache_keys, caches_by_key, fn (cache_key, caches_by_key) ->
        relevant_keys = Map.get( caches_by_key, cache_key, [] )

        if Enum.member?( relevant_keys, request_key ) do
          caches_by_key
        else
          Map.put( caches_by_key, cache_key, [ request_key | relevant_keys ] )
        end
      end )

    %{ state | caches_by_key: caches_by_key }
  end

  defp add_cached_value!( state, request_key, response ) do
    %{ cache: cache } = state

    cache = Map.put( cache, request_key, response )

    %{ state | cache: cache }
  end

end
