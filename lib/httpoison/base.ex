defmodule HTTPoison.Base do
  @moduledoc """
  Provides a default implementation for HTTPoison functions.

  This module is meant to be `use`'d in custom modules in order to wrap the
  functionalities provided by HTTPoison. For example, this is very useful to
  build API clients around HTTPoison:

      defmodule GitHub do
        use HTTPoison.Base

        @endpoint "https://api.github.com"

        def process_request_url(url) do
          @endpoint <> url
        end
      end

  The example above shows how the `GitHub` module can wrap HTTPoison
  functionalities to work with the GitHub API in particular; this way, for
  example, all requests done through the `GitHub` module will be done to the
  GitHub API:

      GitHub.get("/users/octocat/orgs")
      #=> will issue a GET request at https://api.github.com/users/octocat/orgs

  ## Overriding functions

  `HTTPoison.Base` defines the following list of functions, all of which can be
  overridden (by redefining them). The following list also shows the typespecs
  for these functions and a short description.

      # Called in order to process the url passed to any request method before
      # actually issuing the request.
      @spec process_request_url(HTTPoison.Request.t) :: binary
      def process_request_url(%Request{url: url})

      # Called to arbitrarily process the request body before sending it with the
      # request.
      @spec process_request_body(HTTPoison.Request.t) :: binary
      def process_request_body(%Request{body: body})

      # Called to arbitrarily process the request headers before sending them
      # with the request.
      @spec process_request_headers(HTTPoison.Request.t) :: [{binary, term}]
      def process_request_headers(%Request{headers: headers})

      # Called to arbitrarily process the request options before sending them
      # with the request.
      @spec process_request_options(HTTPoison.Request.t) :: keyword
      def process_request_options(%Request{options: options})

      # Called to process the response headers before returning them to the
      # caller.
      @spec process_response_headers([{binary, term}]) :: term
      def process_response_headers(headers)

      # Called before returning the response body returned by a request to the
      # caller.
      @spec process_response_body(binary) :: term
      def process_response_body(body)

      # Used to arbitrarily process the status code of a response before
      # returning it to the caller.
      @spec process_response_status_code(integer) :: term
      def process_response_status_code(status_code)

      # Used when an async request is made; it's called on each chunk that gets
      # streamed before returning it to the streaming destination.
      @spec process_response_chunk(binary) :: term
      def process_response_chunk(chunk)

      # Called before returning the response returned by a request to the caller.
      @spec process_response(Response.t) :: any
      def process_response(%Response{} = response)

  """

  alias HTTPoison.Request
  alias HTTPoison.Response
  alias HTTPoison.AsyncResponse
  alias HTTPoison.Error

  @type headers :: [{atom, binary}] | [{binary, binary}] | %{binary => binary}
  @type body :: binary | {:form, [{atom, any}]} | {:file, binary}
  @type params :: map | keyword

  defmacro __using__(_) do
    quote do
      @type headers :: HTTPoison.Base.headers
      @type body :: HTTPoison.Base.body
      @type params :: HTTPoison.Base.params

      @doc """
      Starts HTTPoison and its dependencies.
      """
      def start, do: :application.ensure_all_started(:httpoison)

      ## Request processors

      @spec process_request_url(Request.t) :: String.t
      def process_request_url(%Request{url: url}) do
        HTTPoison.Base.default_process_url(url)
      end

      @spec process_request_headers(Request.t) :: headers
      def process_request_headers(%Request{headers: headers}) when is_map(headers) do
        Enum.into(headers, [])
      end
      def process_request_headers(%Request{headers: headers}), do: headers

      @spec process_request_body(Request.t) :: body
      def process_request_body(%Request{body: body}), do: body

      @spec process_request_params(Request.t) :: params
      def process_request_params(%Request{params: params}), do: params

      @spec process_request_options(Request.t) :: keyword
      def process_request_options(%Request{options: options}), do: options

      ## Response processors

      @spec process_response(Response.t) :: any
      def process_response(%Response{} = response), do: response

      @spec process_response_headers(headers) :: any
      def process_response_headers(headers), do: headers

      @spec process_response_body(body) :: any
      def process_response_body(body), do: body

      @spec process_response_status_code(integer) :: any
      def process_response_status_code(status_code), do: status_code

      @spec process_response_chunk(any) :: any
      def process_response_chunk(chunk), do: chunk


      @doc false
      @spec transformer(pid) :: :ok
      def transformer(target) do
        HTTPoison.Base.transformer(
          __MODULE__,
          target,
          &process_response_status_code/1,
          &process_response_headers/1,
          &process_response_chunk/1
        )
      end

      @doc ~S"""
      Issues an HTTP request with the given method to the given url.

      This function is usually used indirectly by `get/3`, `post/4`, `put/4`, etc

      Request keys:
        * `method` - HTTP method as an atom (`:get`, `:head`, `:post`, `:put`,
          `:delete`, etc.)
        * `url` - target url as a binary string or char list
        * `headers` - HTTP headers as an orddict (e.g., `[{"Accept", "application/json"}]`)
        * `body` - request body. See more below
        * `params` - an enumerable consisting of two-item tuples that will be appended to the url as query string parameters
        * `options` - Keyword list of options

      Request `:body` key:
        * binary, char list or an iolist
        * `{:form, [{K, V}, ...]}` - send a form url encoded
        * `{:file, "/path/to/file"}` - send a file
        * `{:stream, enumerable}` - lazily send a stream of binaries/charlists

      Request `:options` key:
        * `:timeout` - timeout to establish a connection, in milliseconds. Default is 8000
        * `:recv_timeout` - timeout used when receiving a connection. Default is 5000
        * `:stream_to` - a PID to stream the response to
        * `:async` - if given `:once`, will only stream one message at a time, requires call to `stream_next`
        * `:proxy` - a proxy to be used for the request; it can be a regular url
          or a `{Host, Port}` tuple
        * `:proxy_auth` - proxy authentication `{User, Password}` tuple
        * `:ssl` - SSL options supported by the `ssl` erlang module
        * `:follow_redirect` - a boolean that causes redirects to be followed
        * `:max_redirect` - an integer denoting the maximum number of redirects to follow

      Timeouts can be an integer or `:infinity`

      This function returns `{:ok, response}` or `{:ok, async_response}` if the
      request is successful, `{:error, reason}` otherwise.

      ## Examples

          %Request{method: :post, url:"https://my.website.com", body: "{\"foo\": 3}", headers: [{"Accept", "application/json"}]}
          |> request()

      """
      @spec request(Request.t) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def request(%Request{} = request) do
        params = process_request_params(request)
        url = process_request_url(request) |> request_url(params)

        request = %Request{
          method: request.method,
          url: url,
          headers: process_request_headers(request),
          body: process_request_body(request),
          params: params,
          options: process_request_options(request)
        }

        HTTPoison.Base.request(
          __MODULE__,
          request,
          &process_response/1,
          &process_response_status_code/1,
          &process_response_headers/1,
          &process_response_body/1
        )
      end

      defp request_url(url, nil), do: url
      defp request_url(url, []), do: url
      defp request_url(url, params) do
        cond do
          Map.size(params) === 0 -> url
          URI.parse(url).query   -> url <> "&" <> URI.encode_query(params)
          true                   -> url <> "?" <> URI.encode_query(params)
        end
      end

      @doc """
      Issues an HTTP request with the given method to the given url, raising an
      exception in case of failure.

      `request!/1` works exactly like `request/1` but it returns just the
      response in case of a successful request, raising an exception in case the
      request fails.
      """
      @spec request!(Request.t) :: Response.t | AsyncResponse.t
      def request!(%Request{} = request) do
        case request(request) do
          {:ok, response}                  -> response
          {:error, %Error{reason: reason}} -> raise Error, reason: reason
        end
      end

      @doc """
      Issues a GET request to the given url.

      Returns `{:ok, response}` if the request is successful, `{:error, reason}`
      otherwise.

      See `request/1` for more detailed information.
      """
      @spec get(binary, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def get(url, headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :get, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a GET request to the given url, raising an exception in case of
      failure.

      If the request does not fail, the response is returned.

      See `request!/1` for more detailed information.
      """
      @spec get!(binary, headers, params, keyword) :: Response.t | AsyncResponse.t
      def get!(url, headers \\ [], params \\ %{}, options \\ []) do
        request!(%Request{method: :get, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a PUT request to the given url.

      Returns `{:ok, response}` if the request is successful, `{:error, reason}`
      otherwise.

      See `request/1` for more detailed information.
      """
      @spec put(binary, any, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def put(url, body \\ "", headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :put, url: url, headers: headers, body: body, params: params, options: options})
      end

      @doc """
      Issues a PUT request to the given url, raising an exception in case of
      failure.

      If the request does not fail, the response is returned.

      See `request!/1` for more detailed information.
      """
      @spec put!(binary, any, headers, params, keyword) :: Response.t | AsyncResponse.t
      def put!(url, body \\ "", headers \\ [], params \\ %{}, options \\ []) do
        request!(%Request{method: :put, url: url, headers: headers, body: body, params: params, options: options})
      end

      @doc """
      Issues a HEAD request to the given url.

      Returns `{:ok, response}` if the request is successful, `{:error, reason}`
      otherwise.

      See `request/1` for more detailed information.
      """
      @spec head(binary, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def head(url, headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :head, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a HEAD request to the given url, raising an exception in case of
      failure.

      If the request does not fail, the response is returned.

      See `request!/1` for more detailed information.
      """
      @spec head!(binary, headers, params, keyword) :: Response.t | AsyncResponse.t
      def head!(url, headers \\ [], params \\ %{}, options \\ []) do
        request!(%Request{method: :head, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a POST request to the given url.

      Returns `{:ok, response}` if the request is successful, `{:error, reason}`
      otherwise.

      See `request/1` for more detailed information.
      """
      @spec post(binary, any, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def post(url, body, headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :post, url: url, body: body, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a POST request to the given url, raising an exception in case of
      failure.

      If the request does not fail, the response is returned.

      See `request!/1` for more detailed information.
      """
      @spec post!(binary, any, headers, params, keyword) :: Response.t | AsyncResponse.t
      def post!(url, body, headers \\ [], params \\ %{}, options \\ []) do
        request!(%Request{method: :post, url: url, body: body, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a PATCH request to the given url.

      Returns `{:ok, response}` if the request is successful, `{:error, reason}`
      otherwise.

      See `request/1` for more detailed information.
      """
      @spec patch(binary, any, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def patch(url, body, headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :patch, url: url, body: body, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a PATCH request to the given url, raising an exception in case of
      failure.

      If the request does not fail, the response is returned.

      See `request!/1` for more detailed information.
      """
      @spec patch!(binary, any, headers, params, keyword) :: Response.t | AsyncResponse.t
      def patch!(url, body, headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :patch, url: url, body: body, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a DELETE request to the given url.

      Returns `{:ok, response}` if the request is successful, `{:error, reason}`
      otherwise.

      See `request/1` for more detailed information.
      """
      @spec delete(binary, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def delete(url, headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :delete, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a DELETE request to the given url, raising an exception in case of
      failure.

      If the request does not fail, the response is returned.

      See `request!/1` for more detailed information.
      """
      @spec delete!(binary, headers, params, keyword) :: Response.t | AsyncResponse.t
      def delete!(url, headers \\ [], params \\ %{}, options \\ []) do
        request!(%Request{method: :delete, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Issues an OPTIONS request to the given url.

      Returns `{:ok, response}` if the request is successful, `{:error, reason}`
      otherwise.

      See `request/1` for more detailed information.
      """
      @spec options(binary, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def options(url, headers \\ [], params \\ %{}, options \\ []) do
        request(%Request{method: :options, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Issues a OPTIONS request to the given url, raising an exception in case of
      failure.

      If the request does not fail, the response is returned.

      See `request!/1` for more detailed information.
      """
      @spec options!(binary, headers, params, keyword) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
      def options!(url, headers \\ [], params \\ %{}, options \\ []) do
        request!(%Request{method: :options, url: url, headers: headers, params: params, options: options})
      end

      @doc """
      Requests the next message to be streamed for a given `HTTPoison.AsyncResponse`.

      See `request!/1` for more detailed information.
      """
      @spec stream_next(AsyncResponse.t) :: {:ok, AsyncResponse.t} | {:error, Error.t}
      def stream_next(resp = %AsyncResponse{id: id}) do
        case :hackney.stream_next(id) do
          :ok -> {:ok, resp}
          err -> {:error, %Error{reason: "stream_next/1 failed", id: id}}
        end
      end


      defoverridable Module.definitions_in(__MODULE__)
    end
  end

  @doc false
  def transformer(module, target, process_status_code, process_headers, process_chunk) do
    receive do
      {:hackney_response, id, {:status, code, _reason}} ->
        send(target, %HTTPoison.AsyncStatus{id: id, code: process_status_code.(code)})
        transformer(module, target, process_status_code, process_headers, process_chunk)

      {:hackney_response, id, {:headers, headers}} ->
        send(target, %HTTPoison.AsyncHeaders{id: id, headers: process_headers.(headers)})
        transformer(module, target, process_status_code, process_headers, process_chunk)

      {:hackney_response, id, :done} ->
        send(target, %HTTPoison.AsyncEnd{id: id})

      {:hackney_response, id, {:error, reason}} ->
        send(target, %Error{id: id, reason: reason})

      {:hackney_response, id, {redirect, to, headers}} when redirect in [:redirect, :see_other] ->
        send(target, %HTTPoison.AsyncRedirect{id: id, to: to, headers: process_headers.(headers)})

      {:hackney_response, id, chunk} ->
        send(target, %HTTPoison.AsyncChunk{id: id, chunk: process_chunk.(chunk)})
        transformer(module, target, process_status_code, process_headers, process_chunk)
    end
  end

  @doc false
  def default_process_url(url) do
    case String.slice(url, 0, 12) |> String.downcase() do
      "http://" <> _      -> url
      "https://" <> _     -> url
      "http+unix://" <> _ -> url
      _                   -> "http://" <> url
    end
  end

  defp build_hackney_options(module, %Request{options: options}) do
    timeout = Keyword.get(options, :timeout)
    recv_timeout = Keyword.get(options, :recv_timeout)
    stream_to = Keyword.get(options, :stream_to)
    async = Keyword.get(options, :async)
    ssl = Keyword.get(options, :ssl)
    follow_redirect = Keyword.get(options, :follow_redirect)
    max_redirect = Keyword.get(options, :max_redirect)

    hn_options = Keyword.get(options, :hackney, [])

    hn_options = if timeout, do: [{:connect_timeout, timeout} | hn_options], else: hn_options
    hn_options = if recv_timeout, do: [{:recv_timeout, recv_timeout} | hn_options], else: hn_options
    hn_options = if ssl, do: [{:ssl_options, ssl} | hn_options], else: hn_options
    hn_options = if follow_redirect, do: [{:follow_redirect, follow_redirect} | hn_options], else: hn_options
    hn_options = if max_redirect, do: [{:max_redirect, max_redirect} | hn_options], else: hn_options

    hn_options =
      if stream_to do
        async_option = case async do
          nil   -> :async
          :once -> {:async, :once}
        end
        [async_option, {:stream_to, spawn_link(module, :transformer, [stream_to])} | hn_options]
      else
        hn_options
      end

    hn_options
  end

  defp build_hackney_proxy_options(%Request{options: options, url: url}) do
    proxy =
      if Keyword.has_key?(options, :proxy) do
        Keyword.get(options, :proxy)
      else
        case URI.parse(url).scheme do
          "http"  -> System.get_env("HTTP_PROXY") || System.get_env("http_proxy")
          "https" -> System.get_env("HTTPS_PROXY") || System.get_env("https_proxy")
          _       -> nil
        end
      end

    proxy_auth = Keyword.get(options, :proxy_auth)
    hn_proxy_options = if proxy, do: [{:proxy, proxy}], else: []

    hn_proxy_options =
      if proxy_auth, do: [{:proxy_auth, proxy_auth} | hn_proxy_options], else: hn_proxy_options

    hn_proxy_options
  end

  @doc false
  @spec request(atom, Request.t, fun, fun, fun, fun) :: {:ok, Response.t | AsyncResponse.t} | {:error, Error.t}
  def request(module, %Request{} = request, process_response, process_status_code, process_headers, process_body) do
    hn_proxy_options = build_hackney_proxy_options(request)
    hn_options = hn_proxy_options ++ build_hackney_options(module, request)

    case do_request(request, hn_options) do
      {:ok, status_code, headers} ->
        response(process_response, process_status_code, process_headers, process_body, status_code, headers, "", request)

      {:ok, status_code, headers, client} ->
        case :hackney.body(client) do
          {:ok, body} ->
            response(process_response, process_status_code, process_headers, process_body, status_code, headers, body, request)

          {:error, reason} ->
            {:error, %Error{reason: reason} }
        end

      {:ok, id} ->
        {:ok, %HTTPoison.AsyncResponse{id: id}}

      {:error, reason} ->
        {:error, %Error{reason: reason}}
     end
  end

  defp do_request(%Request{body: {:stream, enumerable}} = request, hn_options) do
    with {:ok, ref} <- :hackney.request(request.method, request.url, request.headers, :stream, hn_options) do
      failures = Stream.transform(enumerable, :ok, fn
        _, :error -> {:halt, :error}
        bin, :ok  -> {[], :hackney.send_body(ref, bin)}
        _, error  -> {[error], :error}
      end) |> Enum.into([])

      case failures do
        []        -> :hackney.start_response(ref)
        [failure] -> failure
      end
    end
  end

  defp do_request(%Request{} = request, hn_options) do
    :hackney.request(request.method, request.url, request.headers, request.body, hn_options)
  end

  defp response(process_response, process_status_code, process_headers, process_body, status_code, headers, body, request) do
    {:ok, %Response{
      status_code: process_status_code.(status_code),
      headers: process_headers.(headers),
      body: process_body.(body),
      request: request
    } |> process_response.()}
  end
end
