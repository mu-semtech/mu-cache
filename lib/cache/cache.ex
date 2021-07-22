defmodule Cache.Registry do
  @moduledoc """
  Maintains all cached requests and can clean them if needed.
  """

  use GenServer

  @type header :: {String.t(), String.t(), any, allowed_groups}
  @type cache_key :: any
  @doc "Allowed groups is currently treated as a string, if none were supplied, we can use nil instead."
  @type allowed_groups :: String.t() | nil

  def find_cache({_method, _full_path, _get_params, _allowed_groups} = key) do
    case GenServer.call(__MODULE__, {:find_cache, key}) do
      {:ok, response} -> response
      {:not_found} -> nil
    end
  end

  def store({_method, _full_path, _get_params, _allowed_groups} = key, response) do
    # IO.puts "Going to store new content"
    # IO.inspect( key, label: "Key to store under" )
    # IO.inspect( response, label: "Response to save" )
    GenServer.call(__MODULE__, {:store, key, response})
  end

  def clear_keys(keys) do
    GenServer.call(__MODULE__, {:clear_keys, keys})
  end

  ###
  # GenServer API
  ###
  def start_link(_) do
    GenServer.start_link(__MODULE__, [%{cache: %{}, caches_by_key: %{}}], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{cache: %{}, caches_by_key: %{}}}
  end

  def handle_call({:find_cache, key}, _from, state) do
    if has_key?(state, key) do
      {:reply, {:ok, Map.get(state.cache, key)}, state}
    else
      {:reply, {:not_found}, state}
    end
  end

  def handle_call({:store, request_key, response}, _from, state) do
    # IO.inspect( request_key, label: "Request key" )
    # IO.inspect( response, label: "Response" )

    %{cache_keys: cache_keys, clear_keys: clear_keys} = response

    # IO.inspect { :cache_keys, cache_keys }
    # IO.inspect { :clear_keys, clear_keys }

    state =
      state
      # update state for clear_keys
      |> clear_keys!(clear_keys)

    # IO.puts "Executed clear keys"

    if cache_keys == [] do
      {:reply, :ok, state}
    else
      # IO.puts "Caching request"
      # update state for new cache
      state =
        state
        |> add_cache_key_dependency!(cache_keys, request_key)
        |> add_cached_value!(request_key, response)

      {:reply, :ok, state}
    end
  end

  def handle_call({:clear_keys, keys}, _from, state) do
    {:reply, :ok, clear_keys!(state, keys)}
  end

  defp has_key?(state, key) do
    Map.has_key?(state.cache, key)
  end

  defp clear_keys!(state, []) do
    state
  end

  defp clear_keys!(state, clear_keys) do
    # We have multiple clear_keys and need to update the state for it.
    %{cache: cache, caches_by_key: caches_by_key} = state

    # IO.inspect(clear_keys, label: "Clearing these keys")
    # IO.inspect(cache, label: "Cache before clearing the keys")

    cache =
      Enum.reduce(clear_keys, cache, fn clear_key, cache ->
        keys_to_remove = Map.get(caches_by_key, clear_key, [])
        maybe_send_cleared_key_to_database!(keys_to_remove)
        cache = Map.drop(cache, keys_to_remove)
        cache
      end)

    # IO.inspect(cache, label: "Cache after clearing the keys")
    caches_by_key = Map.drop(caches_by_key, clear_keys)

    %{state | cache: cache, caches_by_key: caches_by_key}
  end

  defp add_cache_key_dependency!(state, [], _request_key) do
    state
  end

  defp add_cache_key_dependency!(state, cache_keys, request_key) do
    # For each cache_key, we need to see if the request_key is already
    # in the cache_keys and add it if it is not there.
    %{caches_by_key: caches_by_key} = state

    caches_by_key =
      Enum.reduce(cache_keys, caches_by_key, fn cache_key, caches_by_key ->
        relevant_keys = Map.get(caches_by_key, cache_key, [])

        if Enum.member?(relevant_keys, request_key) do
          caches_by_key
        else
          Map.put(caches_by_key, cache_key, [request_key | relevant_keys])
        end
      end)

    %{state | caches_by_key: caches_by_key}
  end

  defp add_cached_value!(state, request_key, response) do
    %{cache: cache} = state

    cache = Map.put(cache, request_key, response)

    %{state | cache: cache}
  end

  defp maybe_send_cleared_key_to_database!(request_key_to_remove) do
    # Write to the database when a cache for a url is cleared
    if Application.get_env(:mu_cache, :log_cache_clear_event) do
        Enum.map(request_key_to_remove, fn req_key ->
            {method, path, query, auth} = req_key
            uuid = Support.generate_uuid()
            auth_escaped = Support.sparql_escape(auth)
            query = """
            PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
            PREFIX mucache: <http://mu.semte.ch/vocabularies/cache/>
            INSERT DATA {
                GRAPH<http://mu.semte.ch/application> {
                    <http://semte.baert.jp.net/cache-clear/v0.1/#{uuid}>    a mucache:CacheClear ;
                                                                            mu:uuid "#{uuid}";
                                                                            mucache:path "#{path}";
                                                                            mucache:method "#{method}";
                                                                            mucache:query "#{query}";
                                                                            mucache:muAuthAllowedGroups \"\"\"#{auth_escaped}\"\"\";
                                                                            mucache:muAuthUsedGroups \"\"\"#{auth_escaped}\"\"\".
                }
            }
            """
            Support.update(query)
        end)
    end
  end
end
