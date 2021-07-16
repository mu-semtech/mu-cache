defmodule Support do
  # environment variables
  def sparql_endpoint() do
    System.get_env("MU_SPARQL_ENDPOINT")
  end
  def application_graph() do
    System.get_env("MU_APPLICATION_GRAPH")
  end
  def sparql_timeout() do
    System.get_env("MU_SPARQL_TIMEOUT")
  end
  def log_level() do
    System.get_env("LOG_LEVEL")
  end

  # uuid helper
  def generate_uuid() do
    UUID.uuid4()
  end

  # graph helper
  def graph() do
    application_graph()
  end

  # query helper
  def _query_get_URL(escaped_query_string) do
    if sparql_timeout() > 0 do
      "#{sparql_endpoint()}?query=#{escaped_query_string}&timeout=#{sparql_timeout()}"
    else
      "#{sparql_endpoint()}?query=#{escaped_query_string}"
    end
  end

  def query(query_string) do
    query_string
    |> URI.encode
    |> _query_get_URL
    |> HTTPoison.get!([{"Accept", "application/json"}])
    |> ( &( &1.body ) ).()
    |> Poison.decode!
  end

  def update(query_string) do
    HTTPoison.post!(
      sparql_endpoint(),
      [
        "query=" <>
        URI.encode_www_form(query_string) <>
        "&format=" <> URI.encode_www_form("application/sparql-results+json")
      ],
      ["Content-Type": "application/x-www-form-urlencoded"],
      []
    )
    |> ( &( &1.body ) ).()
    |> Poison.decode!
  end

  def sparql_escape(value) do
    String.replace(value, "\"", "\\\"")
  end
end
