defmodule Coalesce.Registry do
  @moduledoc """
  Maintains coalescing requests for specific request, dependant on key.
  """

  use GenServer

  def add_connection(pid, connection) do
    {:ok, conn} = GenServer.call(pid, {:add_conn, connection})
    conn
  end

  def assure_status_sent(state, status) do
    if not is_nil(status) and is_nil(state.status) and not is_nil(state.headers) do
      # First time there was a status
      conns =
        state.connections
        |> Enum.map(fn {conn, from} ->
          conn =
            Plug.Conn.merge_resp_headers(conn, state.headers)
            |> Plug.Conn.send_chunked(status)

          {conn, from}
        end)
        |> Enum.flat_map(fn {conn, from} ->
          case push_body_parts(conn, state.body) do
            nil -> []
            conn -> [{conn, from}]
          end
        end)

      %{state | connections: conns, status: status}
    else
      state
    end
  end

  def push_body_parts(conn, body_parts) do
    Enum.reduce_while(body_parts, conn, fn ch, conn ->
      case Plug.Conn.chunk(conn, ch) do
        {:ok, conn} -> {:cont, conn}
        {:error, :closed} -> {:halt, nil}
      end
    end)
  end

  ###
  # GenServer API
  ###
  def start(_) do
    GenServer.start(__MODULE__, [%{}])
  end

  @impl true
  def init(_) do
    {:ok, %{connections: [], headers: nil, body: [], status: nil}}
  end

  @impl true
  def handle_call({:add_conn, conn}, from, state) do
    conn = if not is_nil(state.status) and not is_nil(state.headers) do
        Plug.Conn.merge_resp_headers(conn, state.headers)
        |> Plug.Conn.send_chunked(state.status)
        |> push_body_parts(state.body)
    else
      conn
    end

    conns = [{conn, from} | state.connections]

    new_state = %{state | connections: conns}

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:headers, headers, status}, state) do
    state_with_headers = %{state | headers: headers}
    new_state = assure_status_sent(state_with_headers, status)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:chunk, data, status}, state) do
    new_state = assure_status_sent(state, status)

    conns =
      Enum.flat_map(new_state.connections, fn {conn, from} ->
        case Plug.Conn.chunk(conn, data) do
          {:ok, conn} -> [{conn, from}]
          {:error, :closed} -> []
        end
      end)

    new_state = %{new_state | connections: conns}

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:finished, status}, state) do
    new_state = assure_status_sent(state, status)

    Enum.each(new_state.connections, fn {conn, from} -> GenServer.reply(from, {:ok, conn}) end)

    {:stop, :normal, new_state}
  end
end
