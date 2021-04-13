defmodule Folding.RunningRequest do
  @moduledoc """
  Symbolizes a running request.

  This is a process which runs next to the original request handler,
  accepting requests and sending solutions to all interested entities.
  """

  alias Folding.RunningRequest
  alias Folding.RunningRequestInfo

  use GenServer

  @type t :: %RunningRequest{
          listeners: pid,
          request_info: RunningRequestInfo.t(),
          closed: boolean
        }
  defstruct listeners: [], request_info: RunningRequestInfo.new(), closed: false

  @spec start :: GenServer.on_start()
  @doc """
  Starts a new listener process for the running request.
  """
  def start() do
    # TODO: ensure this process dies if the Mint request dies and ensure
    # the other components know what the new state is then.

    GenServer.start(__MODULE__, nil)
  end

  def init(_) do
    {:ok, %RunningRequest{}}
  end

  @spec add_listener(pid, pid) :: :ok
  @doc """
  Add A listener to this RunningRequest.  The listener will be informed
  about any state as the state arrives.
  """
  def add_listener(pid, listener) do
    # Adds a listener, should also send all known data to that listener
    GenServer.cast(pid, {:add_listener, listener})
  end

  @spec receive_headers(pid, Plug.Conn.headers()) :: :ok
  @doc """
  Headers were received, add them to this process and inform listeners.
  """
  def receive_headers(pid, headers) do
    # Indicates headers were received
    GenServer.cast(pid, {:receive_headers, headers})
  end

  @spec receive_status_code(pid, Plug.Conn.status()) :: :ok
  def receive_status_code(pid, status_code) do
    GenServer.cast(pid, {:receive_status_code, status_code})
  end

  @doc """
  Chunk was received, add it to this process and inform listeners.
  """
  def receive_chunk(pid, chunk) do
    # Indicates a chunk was received
    GenServer.cast(pid, {:receive_chunk, chunk})
  end

  @doc """
  Full request handled, add it to this process and inform listeners.
  """
  def receive_finish(pid, finish) do
    # Indicates the request was finished
    GenServer.cast(pid, {:receive_finish, finish})
  end

  @spec close(pid) :: :ok
  @doc """
  Indicates the request is closed and no new listeners will be added.
  If all listeners are closed, this process may terminate itself.
  """
  def close(pid) do
    GenServer.cast(pid, :close)
    :ok
  end

  def handle_cast({:add_listener, pid}, state) do
    bring_up_to_speed(pid, state.request_info)

    {:noreply, %{state | listeners: [pid | state.listeners]}}
  end

  def handle_cast({:receive_headers, headers}, state) do
    # Inform each listener the headers have arrived
    inform_headers_arrived(state.listeners, headers)

    {:noreply, put_in(state.request_info.headers, headers)}
  end

  def handle_cast({:receive_status_code, status_code}, state) do
    inform_status_code_arrived(state.listeners, status_code)

    {:noreply, put_in(state.request_info.status_code, status_code)}
  end

  def handle_cast({:receive_chunk, chunk}, state) do
    inform_chunk_arrived(state.listeners, chunk)

    {:noreply, update_in(state.request_info.reversed_chunks, &[chunk | &1])}
  end

  def handle_cast({:receive_finish, finish}, state) do
    inform_finished(state.listeners, finish)

    if(state.closed == true) do
      Process.exit(self, :normal)
    else
      new_state =
        %{ state | listeners: [] }

      {:noreply, new_state}
    end
  end

  def handle_cast(:close, state) do
    if state.listeners == [] do
      Process.exit(self, :normal)
    else
      {:noreply, put_in(state.closed, true)}
    end
  end

  @spec bring_up_to_speed(pid, RunningRequestInfo.t()) :: :ok
  defp bring_up_to_speed(pid, request_info) do
    if RunningRequestInfo.got_headers(request_info) do
      inform_headers_arrived([pid], request_info.headers)
    end

    if RunningRequestInfo.got_status_code(request_info) do
      inform_status_code_arrived([pid], request_info.status_code)
    end

    if RunningRequestInfo.got_chunks(request_info) do
      request_info.reversed_chunks
      |> Enum.reverse()
      |> (fn chunk -> inform_chunk_arrived([pid], chunk) end).()
    end

    if RunningRequestInfo.is_finished(request_info) do
      inform_finished([pid], request_info.finish)
    end
  end

  @spec inform_headers_arrived([pid], Plug.Conn.headers()) :: :ok
  defp inform_headers_arrived([], _), do: :ok

  defp inform_headers_arrived([listener | rest], headers) do
    # TODO: cope with case where the headers don't contain mu-cache-keys
    # and inform the listeners about that.  Also inform the registry
    # that this request is currently cancelled.

    GenServer.cast(listener, {:headers, headers})
    inform_headers_arrived(rest, headers)
  end

  @spec inform_status_code_arrived([pid], Plug.Conn.status()) :: :ok
  defp inform_status_code_arrived([], _), do: :ok

  defp inform_status_code_arrived([listener | rest], status_code) do
    GenServer.cast(listener, {:status_code, status_code})
    inform_status_code_arrived(rest, status_code)
  end

  @spec inform_chunk_arrived([pid], Pug.Conn.body()) :: :ok
  defp inform_chunk_arrived([], _), do: :ok

  defp inform_chunk_arrived([listener | rest], chunk) do
    GenServer.cast(listener, {:chunk, chunk})
    inform_chunk_arrived(rest, chunk)
  end

  @spec inform_finished([pid], boolean) :: :ok
  defp inform_finished([], _), do: :ok

  defp inform_finished([listener | rest], finish) do
    GenServer.cast(listener, {:finish, finish})
    inform_finished(rest, finish)
  end
end
