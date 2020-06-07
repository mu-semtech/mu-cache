# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

defmodule CH do
  def system_boolean(name) do
    case String.downcase(System.get_env(name) || "") do
      "true" -> true
      "yes" -> true
      "1" -> true
      "on" -> true
      _ -> false
    end
  end
end

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

config :use_plug_proxy,
  log_cache_keys: CH.system_boolean("LOG_CACHE_KEYS"),
  log_clear_keys: CH.system_boolean("LOG_CLEAR_KEYS"),
  store_cleared_urls: CH.system_boolean("STORE_CLEARED_URLS"),
  default_sparql_endpoint: (System.get_env("MU_SPARQL_ENDPOINT") || "http://localhost:8890/sparql")

# You can configure for your application as:
#
#     config :use_plug_proxy, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:use_plug_proxy, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
