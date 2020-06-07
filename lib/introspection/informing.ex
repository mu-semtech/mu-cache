defmodule Introspection.Informing do
  @moduledoc """
  Responsible for sending cleared URLs to the triplestore backend.
  """

  use GenServer

  @doc """
  This method is responsible for informing others about a cleared URL.

  The specific function will verify that we need to send the URLs and
  only execute if necessary.  The added load is therefore absolutely
  minimal.

  The function returns the arguments it has received so it is easy to
  be inlined.
  """
  @spec store_cleared_urls([String.t()]) :: [String.t()]
  def store_cleared_urls(urls) do
    if(Application.get_env(:use_plug_proxy, :store_cleared_urls)) do
      GenServer.cast(__MODULE__, {:send_clear, urls})
    end

    urls
  end

  ###
  # GenServer API
  ###
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_cast({:send_clear, urls}, _) do
    query = """
      INSERT DATA {
        #{sparql_triples(urls)}
      }
    """

    # TODO: retry query sending on error
    send_query(query)

    {:noreply, nil}
  end

  @spec send_query(String.t()) :: {:ok, any} | {:fail}
  defp send_query(query) do
    poison_options = [recv_timeout: 60_000]
    backend = Application.get_env(:use_plug_proxy, :default_sparql_endpoint)

    try do
      poisonResponse =
        HTTPoison.post!(
          backend,
          [
            "query=" <>
              URI.encode_www_form(query) <>
              "&format=" <> URI.encode_www_form("application/sparql-results+json")
          ],
          poison_options
        )
      {:ok, poisonResponse.body}
    rescue
      exception ->
        IO.inspect(exception, label: "ERROR! Could not write cache clearing to triplestore. Received exception")
        {:fail}
    end
  end

  @spec sparql_triples([{String.t(), String.t(), String.t()}]) :: String.t()
  defp sparql_triples(urls) do
    source_uri = Application.get_env(:use_plug_proxy, :source_uri)

    # convert into a datastructure we can use
    url_statements_list =
      Enum.map(urls, fn {method, base, query, access_rights} ->
        # calculate the real url of the request
        full_url =
          case query do
            "" -> base
            _ -> base <> "?" <> query
          end

        sparql_request_url = sparql_escape_string(full_url)

        # create resource to which we can attach details
        sparql_uri =
          "<http://semantic.works/services/mu-cache/resources/url-invalidations/#{UUID.uuid1()}>"

        # create a uri for the request method (get head patch put ...)
        method_uri =
          "<http://semantic.works/services/mu-cache/resources/cache-methods/#{
            String.downcase(method)
          }>"

        escaped_access_rights = sparql_escape_string( access_rights )

        # send out the clearing resource
        {sparql_uri, method_uri, sparql_request_url, escaped_access_rights}
      end)

    statement_resource_urls =
      url_statements_list
      |> Enum.map(&elem(&1, 0))
      |> Enum.join(", ")

    statement_triples =
      url_statements_list
      |> Enum.map(fn {sparql_uri, method, url, access_rights} ->
        """
        #{sparql_uri} a <http://semantic.works/vocabularies/cache/CacheClearResource>;
          <http://semantic.works/vocabularies/cache/method> #{method};
          <http://semantic.works/vocabularies/cache/accessRights> #{access_rights};
          <http://semantic.works/vocabularies/cache/relativeUrl> #{url}.
        """
      end)
      |> Enum.join("\n\n")

    resource_uri =
      "<http://semantic.works/services/mu-cache/resources/invalidations/#{UUID.uuid1()}>"

    """
    #{resource_uri} a <http://semantic.works/vocabularies/cache/CacheClearEvent>;
       <http://semantic.works/vocabularies/cache/source> <#{source_uri}>;
       <http://semantic.works/vocabularies/cache/clears> #{statement_resource_urls}.

    #{statement_triples}
    """
  end

  @spec sparql_escape_string(String.t()) :: String.t()
  defp sparql_escape_string(url) do
    url
    # Escape escape characters against sparql injection
    |> String.replace("\\", "\\\\")
    # Make sure we don't have dangling doublequotes against sparql injection
    |> String.replace("\"", "\\\"")
    # Wrap in doublequotes
    |> (fn str -> "\"" <> str <> "\"" end).()
  end
end
