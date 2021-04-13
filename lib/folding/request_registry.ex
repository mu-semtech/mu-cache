defmodule Folding.RequestRegistry do
  alias Cache.Registry, as: Cache
  alias Folding.RequestRegistry, as: Registry

  @moduledoc """
  Maintains a registry of outstanding requests which can be subscribed
  to.

  The general idea in this is that we'll have a registry that's
  populated when a request to the backend is started, as well as when
  the request is ended.  This lets us use the cache as a way of sending
  the data.

  Whenever the headers are retrieved for a call, should the response not
  contain any `cache-keys`, we can cancel registration and ensure other
  interested entities perform their own calls to the outside world.

  TODO: we must verify how plug_mint_proxy works with cancelled
  connections.  Would it still be able to fetch the full response and
  store it if needed?
  """
  use GenServer

  defstruct running_map: %{}
  @type t :: %Registry{running_map: %{Cache.header() => pid}}

  def start_link(_) do
    GenServer.start_link(__MODULE__, [nil], name: __MODULE__)
  end

  def init(_) do
    {:ok, %Registry{}}
  end

  def handle_call({:get_pid_or_register, header, conn, pid}, _from, state) do
    if running_request_handler = Map.get(state.running_map, header) do
      conn = Plug.Conn.assign(conn, :cache_plug_pid, pid)
      {:ok, forward_pid} = Folding.ForwardToConn.start(conn)
      Folding.RunningRequest.add_listener(running_request_handler, forward_pid)
      {:reply, {:running, forward_pid}, state}
    else
      # TODO: Do we want to cope with failing to start a RunningRequest?
      {:ok, pid} = Folding.RunningRequest.start()

      state =
        Map.update(state, :running_map, %{}, fn running_map ->
          Map.put(running_map, header, pid)
        end)

      {:reply, {:none, pid}, state}
    end
  end

  def handle_cast({:close, header}, state) do
    running_request_handler = Map.get(state.running_map, header)
    Folding.RunningRequest.close(running_request_handler)

    new_running_map =
      state.running_map
      |> Map.delete(header)

    {:noreply, put_in(state.running_map, new_running_map)}
  end

  @doc """
  Either yields you a PID of a process that is interested in a specific
  result, or creates a manager for you, registers it, and ensures the
  the RequestRegistry knows about it.

  This is your one-stop place to find out if there is an ongoing running
  request for the call you're trying to make.

  Responses:

  - `{:running, pid}` means the request is running, we've constructed
    a forward for you and a process that will handle your Plug.Conn.

  - `{:none, pid}` means no request was running and we've constructed a
    RunningRequest for you.
  """
  @spec get_pid_or_register(Plug.Conn.t()) :: {:running, pid} | {:none, pid}
  def get_pid_or_register(conn) do
    # TODO: implement
    #
    # - We know the PID because we're requesting content right now.
    # - We can trap this for exists, just in case.
    # - We can yield back a registry key, which they can maintain in the Conn's local storage.
    header = Cache.cache_header_for_conn(conn)

    GenServer.call(__MODULE__, {:get_pid_or_register, header, conn, self})
  end

  @doc """
  Closes the received connection for which the RequestRegistry is
  running, ensuring no new requests can be added to it.
  """
  @spec close(Plug.Conn.t()) :: :ok
  def close(conn) do
    GenServer.cast(__MODULE__, {:close, Cache.cache_header_for_conn(conn)})
  end
end
