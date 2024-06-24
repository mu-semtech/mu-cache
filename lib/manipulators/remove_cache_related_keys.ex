defmodule Manipulators.RemoveCacheRelatedKeys do
  @moduledoc """
  Removes cache-keys and clear-keys from the incoming connection.

  The intended use for this is as a response manipulator, removing
  cache keys and clear keys from the server response.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers_inp, connection) do
    new_headers =
      headers_inp
      |> Enum.reject(fn
        {"cache-keys", _} -> true
        {"clear-keys", _} -> true
        _ -> false
      end)

    {new_headers, connection}
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
