defmodule Cartel.Response do
  defstruct [
    status_code: nil,
    body: nil,
    headers: [],
    request: nil
  ]

  @type t :: %__MODULE__{
    status_code: integer,
    body: term,
    headers: list,
    request: Cartel.Request.t()
  }
end