defmodule Manipulators.ConstructFoldingRegistry do
  @moduledoc """
  Constructs a folding registry, ensuring the pid to send information to
  is shared in the backend connection.

  This should be placed on the incoming request.  It plays together with
  Manipulators.InformFoldingRegistry.
  """

  @behaviour ProxyManipulator

  @impl true
  def headers(headers, {conn_in, conn_out}) do
    if Enum.any?(headers, &match?({"cache-keys",_},&1)) do
      pid = Folding.RequestRegistry.get_pid_or_register({})
      enriched_conn_out = Mint.HTTP.put_private(conn_out, :folding_pid, pid)

      {headers, {conn_in, enriched_conn_out}}
    else
      :skip
    end
  end

  @impl true
  def chunk(_, _), do: :skip

  @impl true
  def finish(_, _), do: :skip
end
