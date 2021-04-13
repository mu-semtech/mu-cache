defmodule Manipulators.InformFoldingRegistry do
  alias Folding.RunningRequest, as: Handler
  alias Folding.RequestRegistry, as: Registry

  @moduledoc """
  Informs others interested in this request through the
  Folding.RunningRequest information by a PID stored in the outgoing
  connection's private :folding_pid.

  Assumes the connection already received a folding_pid before the whole
  proxy system started.  Once the proxy is running, we know we're in
  control of sending requests to the backend.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {conn_in, _}) do
    if has_handler(conn_in) do
      Handler.receive_headers(handler_pid(conn_in), headers)
    end

    :skip
  end

  @impl true
  def status_code(status_code, {conn_in, _}) do
    if has_handler(conn_in) do
      Handler.receive_status_code(handler_pid(conn_in), status_code)
    end

    :skip
  end

  @impl true
  def chunk(chunk, {conn_in, _}) do
    if has_handler(conn_in) do
      Handler.receive_chunk(handler_pid(conn_in), chunk)
    end

    :skip
  end

  @impl true
  def finish(finish, {conn_in, _}) do
    if has_handler(conn_in) do
      Handler.receive_finish(handler_pid(conn_in), finish)
      Registry.close(conn_in)
    end

    :skip
  end

  @spec handler_pid(Plug.Conn.t()) :: pid
  defp handler_pid(conn) do
    conn.assigns.running_request_handler
  end

  @spec has_handler(Plug.Conn.t()) :: boolean
  defp has_handler(conn) do
    Map.has_key?(conn.assigns, :running_request_handler)
  end
end
