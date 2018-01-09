defmodule HTTPoison do
  @moduledoc """
  The HTTP client for Elixir.

  The `HTTPoison` module can be used to issue HTTP requests and parse HTTP responses to arbitrary urls.

      iex> HTTPoison.get!("https://api.github.com")
      %HTTPoison.Response{
        status_code: 200,
        headers: [{"content-type", "application/json"}],
        body: "{...}",
        request: %HTTPoison.Request{}
      }

  It's very common to use HTTPoison in order to wrap APIs, which is when the
  `HTTPoison.Base` module shines. Visit the documentation for `HTTPoison.Base`
  for more information.

  Under the hood, the `HTTPoison` module just uses `HTTPoison.Base` (as
  described in the documentation for `HTTPoison.Base`) without overriding any
  default function.

  See `request/1` for more details on how to issue HTTP requests
  """

  use HTTPoison.Base
end
