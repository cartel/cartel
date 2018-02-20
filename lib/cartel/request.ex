defmodule Cartel.Request do
  @enforce_keys [:url]
  defstruct [
    method: :get,
    url: nil,
    headers: [],
    body: "",
    params: %{},
    options: []
  ]

  @type method :: :get | :post | :put | :patch | :delete | :options | :head
  @type headers :: Cartel.Base.headers
  @type body :: Cartel.Base.body

  @type t :: %__MODULE__{
    method: method,
    url: String.t(),
    headers: headers,
    body: body,
    params: map | keyword,
    options: keyword
  }
end