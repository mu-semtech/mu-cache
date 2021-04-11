defmodule Manipulators.StoreResponse do
  alias Cache.Registry, as: Cache

  @moduledoc """
   Stores the response in a shared cache for reuse.

   This manipulator must run as a response manipulator because it needs
   the full response.

   We store the information on what is `conn_out` in from this
   manipulator's perspective as we can hopefully keep that alive in the
   future, even when the client connection has dropped out.  Our
   experimentation shows that to be the Mint request, thus the
   connection to the `backend` hostname.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {conn_in, conn_out}) do
    should_cache = Enum.any?(headers, &match?({"cache-keys", _}, &1))
    should_clear = Enum.any?(headers, &match?({"clear-keys", _}, &1))

    if should_cache or should_clear do
      conn_out_with_headers =
        conn_out
        |> Mint.HTTP.put_private(:mu_cache_should_cache, should_cache)
        |> Mint.HTTP.put_private(:mu_cache_should_clear, should_clear)
        |> Mint.HTTP.put_private(:mu_cache_original_headers, headers)

      {headers, {conn_in, conn_out_with_headers}}
    else
      :skip
    end
  end

  @impl true
  def chunk(chunk, {conn_in, conn_out}) do
    should_cache = Mint.HTTP.get_private(conn_out, :mu_cache_should_cache)

    if should_cache do
      current_chunks = Mint.HTTP.get_private(conn_out, :mu_cache_chunks, [])
      # reversed, see finish
      new_chunks = [chunk | current_chunks]

      conn_out_with_new_chunks = Mint.HTTP.put_private(conn_out, :mu_cache_chunks, new_chunks)

      {chunk, {conn_in, conn_out_with_new_chunks}}
    else
      :skip
    end
  end

  @impl true
  def finish(_, {conn_in, conn_out}) do
    has_cache = Mint.HTTP.get_private(conn_out, :mu_cache_should_cache)

    cond do
      has_cache ->
        reversed_chunks = Mint.HTTP.get_private(conn_out, :mu_cache_chunks, [])
        response_body = Enum.reduce(reversed_chunks, "", &(&1 <> &2))

        all_response_headers = Mint.HTTP.get_private(conn_out, :mu_cache_original_headers)

        allowed_groups =
          all_response_headers
          |> Enum.find({nil, "[]"}, &match?({"mu-auth-allowed-groups", _}, &1))
          |> elem(1)

        cache_keys =
          all_response_headers
          |> Enum.find({nil, "[]"}, &match?({"cache-keys", _}, &1))
          |> elem(1)
          |> Poison.decode!()

        clear_keys =
          all_response_headers
          |> Enum.find({nil, "[]"}, &match?({"clear-keys", _}, &1))
          |> elem(1)
          |> Poison.decode!()

        # IO.inspect( {conn_in.method, conn_in.request_path, conn_in.query_string, allowed_groups}, label: "Signature to store" )

        Cache.store(
          {conn_in.method, conn_in.request_path, conn_in.query_string, allowed_groups},
          %{
            body: response_body,
            headers:
              Enum.reject(all_response_headers, fn
                {"cache-keys", _} -> true
                {"clear-keys", _} -> true
                _ -> false
              end),
            status_code: conn_in.status,
            cache_keys: cache_keys,
            clear_keys: clear_keys,
            allowed_groups: allowed_groups
          }
        )

      Mint.HTTP.get_private(conn_out, :mu_cache_should_clear) ->
        # If we don't cache a response, we need to send the clear keys
        # in another way.
        all_response_headers = Mint.HTTP.get_private(conn_out, :mu_cache_original_headers)

        clear_keys =
          all_response_headers
          |> Enum.find({nil, "[]"}, &match?({"clear-keys", _}, &1))
          |> elem(1)
          |> Poison.decode!()

        IO.inspect(clear_keys, label: "Clear keys")

        Cache.clear_keys(clear_keys)

      true ->
        nil
    end

    :skip
  end
end
