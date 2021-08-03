defmodule Manipulators.CacheKeyLogger do
  @moduledoc """
    Manipulates the response, logging the cache keys and the clear keys
    if this was requested by configuration.
  """
  @behaviour ProxyManipulator

  @impl true
  def headers(headers, _) do
    maybe_log_cache_keys(headers)
    maybe_log_clear_keys(headers)

    :skip
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip

  defp maybe_log_clear_keys(headers) do
    if Application.get_env(:mu_cache, :log_clear_keys) do
      clear_keys = header_value(headers, "clear-keys")

      # credo:disable-for-next-line Credo.Check.Warning.IoInspect
      IO.inspect(clear_keys, label: "Clear keys")
    end
  end

  defp maybe_log_cache_keys(headers) do
    if Application.get_env(:mu_cache, :log_cache_keys) do
      cache_keys = header_value(headers, "cache-keys")

      # credo:disable-for-next-line Credo.Check.Warning.IoInspect
      IO.inspect(cache_keys, label: "Cache keys")
    end
  end

  defp header_value(headers, header_name) do
    header =
      headers
      |> Enum.find(&match?({^header_name, _}, &1))

    if header do
      elem(header, 1)
    end
  end
end
