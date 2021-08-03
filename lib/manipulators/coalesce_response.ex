defmodule Manipulators.CoalesceResponse do
  @moduledoc """
    Manipulates the response, notifying the Coalesce.Registry for this request.
  """

  alias Cache.Registry, as: Cache

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {conn_in, conn_out}) do
    all_response_headers = Mint.HTTP.get_private(conn_out, :mu_cache_original_headers)

    allowed_groups =
      all_response_headers
      |> Enum.find({nil, "[]"}, &match?({"mu-auth-allowed-groups", _}, &1))
      |> elem(1)
      |> Poison.decode!()

    key = {conn_in.method, conn_in.request_path, conn_in.query_string, allowed_groups}

    pid = Cache.get_coalesce_pid(key)

    conn_out =
      conn_out
      |> Mint.HTTP.put_private(:coalesce_pid, pid)
      |> Mint.HTTP.put_private(:coalesce_key, key)

    GenServer.cast(pid, {:headers, headers, conn_in.status})

    {headers, {conn_in, conn_out}}
  end

  @impl true
  def chunk(chunk, {conn_in, conn_out}) do
    pid = Mint.HTTP.get_private(conn_out, :coalesce_pid)
    GenServer.cast(pid, {:chunk, chunk, conn_in.status})

    :skip
  end

  @impl true
  def finish(_, {conn_in, conn_out}) do
    pid = Mint.HTTP.get_private(conn_out, :coalesce_pid)
    key = Mint.HTTP.get_private(conn_out, :coalesce_key)
    Cache.remove_coalesce_key(key)
    GenServer.cast(pid, {:finished, conn_in.status})
    :skip
  end
end
