defmodule Cache.Notify do
  @moduledoc """
  Notifies the backend of relevant cache clear
  """

  use GenServer

  ###
  # GenServer API
  ###
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def clear(urls) do
    GenServer.cast(__MODULE__, urls)
  end

  def handle_cast([], state) do
    { :noreply, state }
  end
  def handle_cast(keys, state) do
    clear_combinations =
      keys
      |> Enum.map( fn
        {_method, _full_path, "", allowed_groups, rewrite_url} -> { rewrite_url, allowed_groups }
        {_method, _full_path, query_params, allowed_groups, rewrite_url } -> { rewrite_url <> "?" <> query_params, allowed_groups }
      end )
      |> Enum.filter( fn {path, _} -> matches_pattern? path end )
      |> IO.inspect( label: "Clear combinations" )

    unless Enum.empty? clear_combinations do
      clear_resources =
        clear_combinations
        |> Enum.map(
          fn {path, allowed_groups} ->
            uuid = UUID.uuid4();
            uri = "http://services.semantic.works/cache/resources/#{uuid}"
            # TODO: make path based on redirected URL
            "
              <#{uri}>
              a cache:Clear;
              mu:uuid #{sparql_escape_string(uuid)};
              cache:path #{sparql_escape_string(path)};
              cache:allowedGroups #{sparql_escape_string(allowed_groups)}.
            "
          end)
        |> Enum.join("\n")

      query = "PREFIX cache: <http://mu.semte.ch/vocabularies/cache/>
        PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
        INSERT DATA {
          #{clear_resources}
        }"

      headers = [
        {"mu-auth-scope", "http://services.semantic.works/cache"},
        {"content-type", "application/sparql-update"},
        {"accept", "application/sparql-results+json"}
      ]
      endpoint = "http://database:8890/sparql"

      {:ok, _response} = HTTPoison.post(endpoint, query, headers) # TODO: retry on failure
    end

    {:noreply, state}
  end

  def matches_pattern?( path ) do
      # TODO: check if pattern matching validates now

    does_pattern_match? =
        Application.get_env(:mu_cache, :push_regex)
        # [ ~r/messages/, ~r/tasks/ ]
        |> Enum.any?( fn regex -> Regex.match?( regex, path ) end )

    if Application.get_env(:mu_cache, :log_push_regex)  do
      IO.puts "Does pattern #{path} match? #{does_pattern_match?}"
    end

    does_pattern_match?
  end

  def sparql_escape_string(string) do
    cleaned_string =
      string
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
    "\"\"\"#{cleaned_string}\"\"\""
  end

end
