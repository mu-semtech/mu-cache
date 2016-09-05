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
    GenServer.start_link( __MODULE__, [%{cache: %{}}], name: __MODULE__ )
  end

  def init(_) do
    {:ok, %{cache: %{}}}
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
    cache = Map.put( state.cache, { method, location }, response )
    { :reply, :ok, Map.put( state, :cache, cache ) }
  end

  defp has_key?( state, key ) do
    Map.has_key?( state.cache, key )
  end
end
