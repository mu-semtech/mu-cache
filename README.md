# mu-elixir-cache

An drop-in replacement for mu-cache implemented in Elixir.

_Now extended with some extra features for clearing by delta._

## configuration

As a default mu-elixir-cache works like mu-cache transparantly.  No
configuration is needed for it operate.  Optional configuration below.

## debugging

Debugging of cache keys is helped by following environment variables:

  - `LOG_CACHE_KEYS`: Logs received cache key to a response
  - `LOG_CLEAR_KEYS`: Logs received clear keys either as a response, or explicitly received through ./mu/delta.
