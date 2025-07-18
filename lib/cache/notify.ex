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
    # TODO: filter paths so we onlyyieldinteresting paths

    # keys_to_remove
    # |> Enum.map( fn
    #   ({_method, _full_path, "", _allowed_groups, rewrite_url}) -> rewrite_url
    #   ({_method, _full_path, query_params, _allowed_groups, rewrite_url}) -> rewrite_url <> "?" <> query_params
    # end )
    # |> Cache.Notify.clear()

    clear_resources = keys
    |> Enum.map( fn
      {_method, _full_path, "", allowed_groups, rewrite_url} -> { rewrite_url, allowed_groups }
      {_method, _full_path, query_params, allowed_groups, rewrite_url } -> { rewrite_url <> "?" <> query_params, allowed_groups }
    end )
    |> Enum.map( fn {path, allowed_groups} ->
      uuid = UUID.uuid4();
      uri = "http://services.semantic.works/cache/resources/#{uuid}"
      "
        <#{uri}>
          a cache:Clear;
          mu:uuid \"\"\"#{uuid}\"\"\";
          cache:path \"\"\"#{path}\"\"\";
          cache:allowedGroups \"\"\"#{allowed_groups}\"\"\".
          " # TODO: escape the path!
      # TODO: make path based on redirected URL
    end)
    |> Enum.join("\n")

    query = "PREFIX cache: <http://mu.semte.ch/vocabularies/cache/>
      PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
      INSERT DATA {
        #{clear_resources}
      }"

    IO.puts(query)

    headers = [
      {"mu-auth-scope", "http://services.semantic.works/cache"},
      {"content-type", "application/sparql-update"},
      {"accept", "application/sparql-results+json"}
    ]
    endpoint = "http://database:8890/sparql"

    {:ok, _response} = HTTPoison.post(endpoint, query, headers) # TODO: retry on failure
    {:noreply, state}
  end
end
