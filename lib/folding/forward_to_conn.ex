defmodule Folding.ForwardToConn do
  @moduledoc """
  Handles a request when there's already another connection making the
  same request.

  Forwards the necessary information to that request.  If it turns out
  there are no cache keys, a request will be executed against the
  backend and the response will be sent from there.  As such, this
  handles the cache where a running request existed when this request
  started out.
  """

  use GenServer

  @type t :: Plug.Conn.t()

  # TODO: if the response does not contain cache_keys, we should cancel
  # the listening in itself and start making our own requests.

  @spec start(Plug.Conn.t()) :: GenServer.on_start()
  def start(conn) do
    GenServer.start(__MODULE__, conn)
  end

  @impl true
  @spec init(Plug.Conn.t()) :: {:ok, t}
  def init(conn) do
    {:ok, conn}

    # TODO: Ensure this process is linked to a parent process. If that
    # dies, we should die too.
  end

  @impl true
  def handle_cast({:headers, headers}, conn) do
    {:noreply, put_in(conn.resp_headers, headers)}
  end

  @impl true
  def handle_cast({:status_code, status_code}, conn) do
    # TODO: cope with failure states
    IO.inspect(status_code, label: "received status code")
    conn = Plug.Conn.send_chunked(conn, status_code)
    {:noreply, put_in(conn.status, status_code)}
  end

  @impl true
  def handle_cast({:chunk, chunk}, conn) do
    conn =
      if conn.state == :unset do
        # TODO: don't hardcode this status
        Plug.Conn.send_chunked(conn, 200)
      else
        conn
      end

    {:ok, conn} = Plug.Conn.chunk(conn, chunk)
    {:noreply, conn}
  end

  @impl true
  def handle_cast({:finish, _finish}, conn) do
    conn =
      if conn.state == :unset do
        # TODO: don't hardcode this status
        conn = Plug.Conn.send_resp(conn, conn.status, 200)
      else
        conn
      end

    send(conn.assigns.cache_plug_pid, {:finish_plug, put_in(conn.state, :sent)})

    # TODO: Stop this process, we don't need it anymore
    {:noreply, nil}
  end
end
