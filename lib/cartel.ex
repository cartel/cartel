defmodule Cartel do
  @moduledoc """
  The HTTP client for Elixir.

  The `Cartel` module can be used to issue HTTP requests and parse HTTP responses to arbitrary urls.

      iex> Cartel.get!("https://api.github.com")
      %Cartel.Response{
        status_code: 200,
        headers: [{"content-type", "application/json"}],
        body: "{...}",
        request: %Cartel.Request{}
      }

  It's very common to use Cartel in order to wrap APIs, which is when the
  `Cartel.Base` module shines. Visit the documentation for `Cartel.Base`
  for more information.

  Under the hood, the `Cartel` module just uses `Cartel.Base` (as
  described in the documentation for `Cartel.Base`) without overriding any
  default function.

  See `request/1` for more details on how to issue HTTP requests
  """

  use Cartel.Base
end
