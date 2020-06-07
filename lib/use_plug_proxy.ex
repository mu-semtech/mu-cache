alias UsePlugProxy.Cache, as: Cache

defmodule UsePlugProxy do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  get "/cachecanhasresponse" do
    send_resp(conn, 200, "debugging is a go")
  end

  match "/.mu/clear-keys" do
    conn
    |> Plug.Conn.get_req_header("clear-keys")
    |> Enum.map(&Poison.decode!/1)
    # remove nil values
    |> Enum.filter(& &1)
    |> Enum.map(&maybe_log_clear_keys/1)
    |> Enum.map(&Cache.clear_keys/1)

    Plug.Conn.send_resp(conn, 204, "")
  end

  match "/*path" do
    full_path = Enum.reduce(path, "", fn a, b -> b <> "/" <> a end)
    known_allowed_groups = get_string_header(conn.req_headers, "mu-auth-allowed-groups")
    conn = Plug.Conn.fetch_query_params(conn)

    cond do
      known_allowed_groups == nil ->
        # without allowed groups, we don't know the access rights
        calculate_response_from_backend(full_path, conn)

      cached_value =
          Cache.find_cache({conn.method, full_path, conn.query_string, known_allowed_groups}) ->
        # with allowed groups and a cache, we should use the cache
        respond_with_cache(conn, cached_value)

      true ->
        # without a cache, we should consult the backend
        IO.puts("Cache miss")
        calculate_response_from_backend(full_path, conn)
    end
  end

  defp maybe_log_clear_keys(clear_keys) do
    if Application.get_env(:use_plug_proxy, :log_clear_keys) do
      IO.inspect(clear_keys, label: "Clear keys")
    end

    clear_keys
  end

  defp maybe_log_cache_keys(cache_keys) do
    if Application.get_env(:use_plug_proxy, :log_cache_keys) do
      IO.inspect(cache_keys, label: "Cache keys")
    end

    cache_keys
  end

  @spec calculate_response_from_backend(String.t, Plug.Conn.t) :: Plug.Conn.t
  defp calculate_response_from_backend(full_path, conn) do
    url = "http://backend/" <> full_path

    url =
      case conn.query_string do
        "" -> url
        query -> url <> "?" <> query
      end

    opts = PlugProxy.init(url: url)

    processors = %{
      header_processor: fn headers, _conn, state ->
        headers = downcase_headers(headers)

        {headers, cache_keys} = extract_json_header(headers, "cache-keys")
        {headers, clear_keys} = extract_json_header(headers, "clear-keys")

        maybe_log_cache_keys( cache_keys )
        maybe_log_clear_keys( clear_keys )

        {headers,
         %{
           state
           | headers: headers,
             allowed_groups: get_string_header(headers, "mu-auth-allowed-groups"),
             cache_keys: cache_keys,
             clear_keys: clear_keys
         }}
      end,
      chunk_processor: fn chunk, state ->
        # IO.puts "Received chunk:"
        # IO.inspect chunk
        {chunk, %{state | body: state.body <> chunk}}
      end,
      body_processor: fn body, state ->
        # IO.puts "Received body:"
        # IO.inspect body
        {body, %{state | body: state.body <> body}}
      end,
      finish_hook: fn state ->
        # IO.puts "Fully received body"
        # IO.puts state.body
        # IO.puts "Current state:"
        # IO.inspect state
        Cache.store({conn.method, full_path, conn.query_string, state.allowed_groups}, state)
        {true, state}
      end,
      state: %{
        is_processor_state: true,
        body: "",
        headers: %{},
        status_code: 200,
        cache_keys: [],
        clear_keys: [],
        allowed_groups: nil
      }
    }

    conn
    |> Map.put(:processors, processors)
    |> PlugProxy.call(opts)
  end

  defp respond_with_cache(conn, cached_value) do
    conn
    |> merge_resp_headers(cached_value.headers)
    |> send_resp(200, cached_value.body)
  end

  defp extract_json_header(headers, header_name) do
    case List.keyfind(headers, header_name, 0) do
      {^header_name, keys} ->
        new_headers = List.keydelete(headers, header_name, 0)
        {new_headers, Poison.decode!(keys)}

      _ ->
        {headers, []}
    end
  end

  defp get_string_header(headers, header_name) do
    case List.keyfind(headers, header_name, 0) do
      {^header_name, string} ->
        string

      _ ->
        nil
    end
  end

  defp downcase_headers(headers) do
    Enum.map(headers, fn {header, content} ->
      {String.downcase(header), content}
    end)
  end
end
