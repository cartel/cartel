# Cartel HTTP Client

HTTP client for Elixir, forked from [HTTPoison](https://github.com/edgurgel/httpoison)

## Note about broken ssl in Erlang 19
Until this [issue](https://bugs.erlang.org/browse/ERL-192) is fixed ssl handshakes may fail. If you receive this error:
```
{:error, %Cartel.Error{id: nil, reason: :closed}}
```
Try the following fix:
```elixir
Cartel.get("https://example.com/", [], %{}, ssl: [{:versions, [:'tlsv1.2']}])
```

## But... why fork HTTPoison?

Cartel uses request structs for every request.

## Installation

First, add Cartel to your `mix.exs` dependencies:

```elixir
def deps do
  [{:cartel, "~> 0.1"}]
end
```

and run `$ mix deps.get`. Add `:cartel` to your applications list if your Elixir version is 1.3 or lower:

```elixir
def application do
  [applications: [:cartel]]
end
```

## Usage

```elixir
iex> Cartel.start()
iex> Cartel.get!("http://httparrot.herokuapp.com/get")
%Cartel.Response{
  body: "{\n  \"args\": {},\n  \"headers\": {} ...",
  headers: [{"Connection", "keep-alive"}, {"Server", "Cowboy"},
  {"Date", "Sat, 06 Jun 2015 03:52:13 GMT"}, {"Content-Length", "495"},
  {"Content-Type", "application/json"}, {"Via", "1.1 vegur"}],
  status_code: 200
}
iex> Cartel.get!("http://localhost:1")
** (Cartel.Error) :econnrefused
iex> Cartel.get("http://localhost:1")
{:error, %Cartel.Error{id: nil, reason: :econnrefused}}

iex> Cartel.post("http://httparrot.herokuapp.com/post", "{\"body\": \"test\"}", [{"Content-Type", "application/json"}])
{:ok, %Cartel.Response{body: "{\n  \"args\": {},\n  \"headers\": {\n    \"host\": \"httparrot.herokuapp.com\",\n    \"connection\": \"close\",\n    \"accept\": \"application/json\",\n    \"content-type\": \"application/json\",\n    \"user-agent\": \"hackney/1.6.1\",\n    \"x-request-id\": \"4b85de44-6227-4480-b506-e3b9b4f0318a\",\n    \"x-forwarded-for\": \"76.174.231.199\",\n    \"x-forwarded-proto\": \"http\",\n    \"x-forwarded-port\": \"80\",\n    \"via\": \"1.1 vegur\",\n    \"connect-time\": \"1\",\n    \"x-request-start\": \"1475945832992\",\n    \"total-route-time\": \"0\",\n    \"content-length\": \"16\"\n  },\n  \"url\": \"http://httparrot.herokuapp.com/post\",\n  \"origin\": \"10.180.37.142\",\n  \"form\": {},\n  \"data\": \"{\\\"body\\\": \\\"test\\\"}\",\n  \"json\": {\n    \"body\": \"test\"\n  }\n}",
    headers: [{"Connection", "keep-alive"}, {"Server", "Cowboy"},
    {"Date", "Sat, 08 Oct 2016 16:57:12 GMT"}, {"Content-Length", "681"},
    {"Content-Type", "application/json"}, {"Via", "1.1 vegur"}],
status_code: 200}}
```

You can also easily pattern match on the `Cartel.Response` struct:

```elixir
case Cartel.get(url) do
  {:ok, %Cartel.Response{status_code: 200, body: body}} ->
    IO.puts(body)

  {:ok, %Cartel.Response{status_code: 404}} ->
    IO.puts("Not found ಥ_ಥ")

  {:error, %Cartel.Error{reason: reason}} ->
    IO.inspect(reason)
end
```

Using `Cartel.Request` structs:

```elixir
request =
  %Cartel.Request{
    method: :post,
    url: "http://httparrot.herokuapp.com/post",
    body: "{\"body\": \"test\"}",
    headers: [{"Content-Type", "application/json"}]
  }

case Cartel.request(request) do
  {:ok, %Cartel.Response{status_code: 200, body: body}} ->
    IO.puts(body)

  {:ok, %Cartel.Response{status_code: 429}} ->
    :timer.sleep(1000)
    IO.puts("Trying one more time...")
    Cartel.request(request)

  {:ok, %Cartel.Response{status_code: 404}} ->
    IO.puts("Not found ಥ_ಥ")

  {:error, %Cartel.Error{reason: reason}} ->
    IO.inspect(reason)
end
```

### Options

There are a number of supported options(*not to be confused with the HTTP options method*), documented [here](https://hexdocs.pm/cartel/Cartel.html#request/5), that can be added to your request. The example below shows the use of the `:ssl` and `:recv_timeout` options for a post request to an api that requires a bearer token. The `:ssl` option allows you to set options accepted by th [Erlang SSL module](http://erlang.org/doc/man/ssl.html), and `:recv_timeout` sets a timeout on receiving a response, the default is 5000ms.

```elixir
token = "some_token_from_another_request"
url = "https://example.com/api/endpoint_that_needs_a_bearer_token"
headers = ["Authorization": "Bearer #{token}", "Accept": "Application/json; Charset=utf-8"]
options = [ssl: [{:versions, [:'tlsv1.2']}], recv_timeout: 500]
{:ok, response} = Cartel.get(url, headers, %{}, options)
```

And the example below shows the use of the `:ssl` options for a post request to an api that requires a client certification.

```elixir
url = "https://example.org/api/endpoint_that_needs_client_cert"
options = [ssl: [certfile: "certs/client.crt"]]
{:ok, response} = Cartel.post(url, [], %{}, options)
```

### Wrapping `Cartel.Base`

You can also use the `Cartel.Base` module in your modules in order to make
cool API clients or something. The following example wraps `Cartel.Base` in
order to build a client for the GitHub API
([Poison](https://github.com/devinus/poison) is used for JSON decoding):

```elixir
defmodule GitHub do
  use Cartel.Base

  @expected_fields ~w(
    login id avatar_url gravatar_id url html_url followers_url
    following_url gists_url starred_url subscriptions_url
    organizations_url repos_url events_url received_events_url type
    site_admin name company blog location email hireable bio
    public_repos public_gists followers following created_at updated_at
  )

  def process_request_url(url) do
    "https://api.github.com" <> url
  end

  def process_response_body(body) do
    body
    |> Poison.decode!()
    |> Map.take(@expected_fields)
    |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
  end
end
```

```elixir
iex> GitHub.start()
iex> GitHub.get!("/users/myfreeweb").body[:public_repos]
37
```

It's possible to extend the functions listed below:

```elixir
def process_request_url(%Request{url: url}), do: url

def process_request_headers(%Request{headers: headers}) when is_map(headers) do
  Enum.into(headers, [])
end
def process_request_headers(%Request{headers: headers}), do: headers

def process_request_body(%Request{body: body}), do: body

def process_request_params(%Request{params: params}), do: params

def process_request_options(%Request{options: options}), do: options

def process_response(%Response{} = response), do: {:ok, response}

def process_response_headers(headers), do: headers

def process_response_body(body), do: body

def process_response_status_code(status_code), do: status_code

def process_response_chunk(chunk), do: chunk
```

### Async requests

Cartel now comes with async requests!

```elixir
iex> Cartel.get!("https://github.com/", [], %{}, stream_to: self)
%Cartel.AsyncResponse{id: #Reference<0.0.0.1654>}
iex> flush
%Cartel.AsyncStatus{code: 200, id: #Reference<0.0.0.1654>}
%Cartel.AsyncHeaders{headers: %{"Connection" => "keep-alive", ...}, id: #Reference<0.0.0.1654>}
%Cartel.AsyncChunk{chunk: "<!DOCTYPE html>...", id: #Reference<0.0.0.1654>}
%Cartel.AsyncEnd{id: #Reference<0.0.0.1654>}
:ok
```

### Cookies

Cartel allows you to send cookies:

```elixir
iex> Cartel.get!("http://httparrot.herokuapp.com/cookies", [], %{}, hackney: [cookie: ["session=a933ec1dd923b874e691; logged_in=true"]])
%Cartel.Response{body: "{\n  \"cookies\": {\n    \"session\": \"a933ec1dd923b874e691\",\n    \"logged_in\": \"true\"\n  }\n}",
 headers: [{"Connection", "keep-alive"}, ...],
 status_code: 200}
```

You can also receive cookies from the server by reading the `"set-cookie"` headers in the response:

```elixir
iex(1)> response = Cartel.get!("http://httparrot.herokuapp.com/cookies/set?foo=1")
iex(2)> cookies = Enum.filter(response.headers, fn
...(2)> {"Set-Cookie", _} -> true
...(2)> _ -> false
...(2)> end)
[{"Set-Cookie", "foo=1; Version=1; Path=/"}]
```

You can see more usage examples in the test files (located in the
[`test/`](test)) directory.

### Connection Pools

Normally **hackney** [opens and closes connections on demand](https://github.com/benoitc/hackney#reuse-a-connection), but it also creates a [default pool](https://github.com/benoitc/hackney#use-the-default-pool) of connections which are reused for requests to the same host. If the connection and host support keepalive, the connection is kept open until explicitly closed.

To use the default pool, you can just declare it as an option:

```elixir
Cartel.get("httpbin.org/get", [], %{}, hackney: [pool: :default])
```

It is possible to use different pools for different purposes when a more fine grained allocation of resources is necessary.

#### Simple pool declaration

The easiest way is to just pass the name of the pool, and hackney will create it if it doesn't exist. Pools are independent from each other (they won't compete for connections) and are created with the default configuration.

```elixir
Cartel.get("httpbin.org/get", [], %{}, hackney: [pool: :first_pool])
Cartel.get("httpbin.org/get", [], %{}, hackney: [pool: :second_pool])
```

#### Explicit pool creation

If you want to use different configuration options you can create a pool manually [when your app starts](http://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html#the-application-callback) with `:hackney_pool.start_pool/2`.

```elixir
:ok = :hackney_pool.start_pool(:first_pool, [timeout: 15000, max_connections: 100])
```

From the already linked [hackney's readme](https://github.com/benoitc/hackney#use-the-default-pool):

> `timeout` is the time we keep the connection alive in the pool, `max_connections` is the number of connections maintained in the pool. Each connection in a pool is monitored and closed connections are removed automatically.

#### Pools as supervised processes

A third option is to add the pool as part of your supervision tree:

```elixir
children = [
  :hackney_pool.child_spec(:first_pool, [timeout: 15000, max_connections: 100])
]
```

Add that to the application supervisor and `first_pool` will be available to be used by Cartel/hackney.


## License

MIT License. See the `LICENSE` file for more details.
