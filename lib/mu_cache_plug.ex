defmodule MuCachePlug do
  alias Cache.Registry, as: Cache

  @moduledoc """
  Router for receiving cache requests.
  """
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  @request_manipulators []
  @response_manipulators [
    Manipulators.CacheKeyLogger,
    Manipulators.StoreResponse,
    Manipulators.InformFoldingRegistry,
    Manipulators.RemoveCacheRelatedKeys
  ]
  @manipulators ProxyManipulatorSettings.make_settings(
                  @request_manipulators,
                  @response_manipulators
                )

  get "/cachecanhasresponse" do
    send_resp(conn, 200, "debugging is a go")
  end

  match "/.mu/clear-keys" do
    conn
    |> Plug.Conn.get_req_header("clear-keys")
    |> Enum.map(&Poison.decode!/1)
    # remove nil values
    |> Enum.filter(& &1)
    |> Enum.map(&maybe_log_delta_clear_keys/1)
    |> Enum.map(&Cache.clear_keys/1)

    Plug.Conn.send_resp(conn, 204, "")
  end

  match "/*path" do
    full_path = conn.request_path
    known_allowed_groups = get_string_header(conn.req_headers, "mu-auth-allowed-groups")
    conn = Plug.Conn.fetch_query_params(conn)

    # IO.inspect(known_allowed_groups, label: "Known allowed groups")
    # IO.inspect(Cache.may_cache_method(conn.method), label: "May cache method")
    # IO.inspect(Cache.cache_header_for_conn(conn), label: "Cache header")

    cond do
      known_allowed_groups == nil || !Cache.may_cache_method(conn.method) ->
        # without allowed groups, we don't know the access rights
        # calculate_response_from_backend(full_path, conn)
        # IO.puts("Not allowed to cache request")
        ConnectionForwarder.forward(conn, path, "http://backend/", @manipulators)

      cached_value = Cache.find_cache(Cache.cache_header_for_conn(conn)) ->
        # with allowed groups and a cache, we should use the cache
        # IO.puts("From cache")
        respond_with_cache(conn, cached_value)

      true ->
        # without a cache, we should consult the backend
        # IO.inspect(
        #   {conn.method, full_path, conn.query_string, known_allowed_groups}, label: "Cache miss for signature")

        case Folding.RequestRegistry.get_pid_or_register(conn) do
          {:running, _pid} ->
            # IO.puts("FOUND RUNNING (folding)")
            # This is handled by Folding.ForwardToConn now :)

            # This should wait for the connection to be finished
            receive do
              {:finish_plug, plug} ->
                plug
            end

          # :ok

          {:none, pid} ->
            # IO.puts("NONE RUNNING (booting)")
            # We received a runinng request, we must store it so we can
            # forward data to it.
            conn = Plug.Conn.assign(conn, :running_request_handler, pid)
            ConnectionForwarder.forward(conn, path, "http://backend/", @manipulators)
        end
    end

    # TODO: I think we must return the plug here, and therefore should
    # wait in one of the earlier steps.
  end

  defp respond_with_cache(conn, cached_value) do
    conn
    |> merge_resp_headers(cached_value.headers)
    |> send_resp(200, cached_value.body)
  end

  defp maybe_log_delta_clear_keys(clear_keys) do
    if Application.get_env(:mu_cache, :log_clear_keys) do
      # credo:disable-for-next-line Credo.Check.Warning.IoInspect
      IO.inspect(clear_keys, label: "Clear keys")
    end
  end

  defp get_string_header(headers, header_name) do
    headers
    |> List.keyfind(header_name, 0, {nil, nil})
    |> elem(1)
  end
end
