defmodule Folding.RunningRequestInfo do
  alias Folding.RunningRequestInfo, as: RunningRequestInfo

  @type state :: :start | :headers | :status | :chunking | :finish

  @type t :: %RunningRequestInfo{
          headers: Plug.Conn.headers() | :unset,
          status_code: Plug.Conn.status() | :unset,
          # reversed!
          reversed_chunks: [Plug.Conn.body()] | :unset,
          finish: boolean | :unset
        }
  defstruct headers: :unset, status_code: :unset, reversed_chunks: :unset, finish: :unset

  @type new :: %RunningRequestInfo{}
  @doc """
  Constructs a new RunningRequestInfo in which you can dump some state.
  """
  def new() do
    %RunningRequestInfo{}
  end

  @spec got_headers(t) :: boolean
  @doc """
  Did we receive headers yet?
  """
  def got_headers(request_info) do
    request_info.headers != :unset
  end

  @spec got_status_code(t) :: boolean
  def got_status_code(request_info) do
    request_info.status_code != :unset
  end

  @spec got_chunks(t) :: boolean
  @doc """
  Have we received any chunks or are we past the chunking stage?
  """
  def got_chunks(request_info) do
    request_info.reversed_chunks != :unset
    || request_info.finish != :unset
  end

  @spec is_finished(t) :: boolean
  @doc """
  Has this request finished running?
  """
  def is_finished(request_info) do
    request_info.finish != :unset
  end
end
