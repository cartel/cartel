defmodule CartelBaseTest do
  use ExUnit.Case
  import :meck

  defmodule Example do
    use Cartel.Base
    def process_request_url(%Cartel.Request{url: url}), do: "http://" <> url
    def process_request_body(%Cartel.Request{body: body}), do: {:req_body, body}
    def process_request_headers(%Cartel.Request{headers: headers}), do: {:req_headers, headers}
    def process_request_params(%Cartel.Request{params: params}), do: params
    def process_request_options(%Cartel.Request{options: options}), do: Keyword.put(options, :timeout, 10)
    def process_response(response), do: {:ok, {:resp, response}}
    def process_response_body(body), do: {:resp_body, body}
    def process_response_headers(headers), do: {:resp_headers, headers}
    def process_response_status_code(code), do: {:resp_status_code, code}
  end

  defmodule ExampleDefp do
    use Cartel.Base
    defp process_request_url(%Cartel.Request{url: url}), do: "http://" <> url
    defp process_request_body(%Cartel.Request{body: body}), do: {:req_body, body}
    defp process_request_headers(%Cartel.Request{headers: headers}), do: {:req_headers, headers}
    defp process_request_params(%Cartel.Request{params: params}), do: params
    defp process_request_options(%Cartel.Request{options: options}), do: Keyword.put(options, :timeout, 10)
    defp process_response(response), do: {:ok, {:resp, response}}
    defp process_response_body(body), do: {:resp_body, body}
    defp process_response_headers(headers), do: {:resp_headers, headers}
    defp process_response_status_code(code), do: {:resp_status_code, code}
  end

  defmodule ExampleParams do
    use Cartel.Base
    def process_request_url(%Cartel.Request{url: url}), do: "http://" <> url
    def process_request_params(%Cartel.Request{params: params}) do
      Map.merge(params, %{key: "fizz"})
    end
  end

  defmodule ExampleRetry do
    use Cartel.Base
    def process_request_options(%Cartel.Request{options: options}) do
      Keyword.update(options, :try_count, 1, &(&1 + 1))
    end
    def process_response(%Cartel.Response{request: request} = response) do
      tries = Keyword.get(request.options, :try_count, 1)
      max_tries = Keyword.get(request.options, :max_tries, false)
      case response do
        %{status_code: 429} -> retry(request, max_tries, tries)
        _response           -> {:ok, response}
      end
    end
    def retry(request, false, _), do: request(request)
    def retry(request, max_tries, tries) when tries < max_tries, do: request(request)
    def retry(_, max_tries, tries) do
      {:error, %Cartel.Error{reason: "too many tries [#{tries} of #{max_tries}]"}}
    end
  end

  setup do
    new :hackney
    on_exit fn -> unload() end
    :ok
  end

  test "request body using Example" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: {:req_headers, []},
        body: {:req_body, "body"},
        params: %{},
        options: [{:timeout, 10}]
      }

    expect(:hackney, :request, [{
      [req.method, req.url, req.headers, req.body, [{:connect_timeout, 10}]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Example.post!("localhost", "body") ==
      {:resp,
        %Cartel.Response{
          status_code: {:resp_status_code, 200},
          headers: {:resp_headers, "headers"},
          body: {:resp_body, "response"},
          request: req
        }
      }

    assert validate :hackney
  end

  test "request body using ExampleDefp" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: {:req_headers, []},
        body: {:req_body, "body"},
        params: %{},
        options: [{:timeout, 10}]
      }

    expect(:hackney, :request, [{
      [req.method, req.url, req.headers, req.body, [{:connect_timeout, 10}]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert ExampleDefp.post!("localhost", "body") ==
      {:resp,
        %Cartel.Response{
          status_code: {:resp_status_code, 200},
          headers: {:resp_headers, "headers"},
          body: {:resp_body, "response"},
          request: req
        }
      }

    assert validate :hackney
  end

  test "request body using params example" do
    req =
      %Cartel.Request{
        method: :get,
        url: "http://localhost?foo=bar&key=fizz",
        headers: [],
        body: "",
        params: %{key: "fizz", foo: "bar"},
        options: []
      }

    expect(:hackney, :request, [{
      [req.method, req.url, req.headers, req.body, []],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert ExampleParams.get!("localhost", [], %{foo: "bar"}) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "request body with retries" do
    req =
      %Cartel.Request{
        method: :get,
        url: "http://localhost",
        headers: [],
        body: "",
        params: %{},
        options: [max_tries: 3, try_count: 3]
      }

    expect(:hackney, :request, [{
      [req.method, req.url, req.headers, req.body, []],
      loop([
        {:ok, 429, "headers", :client},
        {:ok, 429, "headers", :client},
        {:ok, 200, "headers", :client}
      ])
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert ExampleRetry.get!("localhost", [], %{}, max_tries: 3) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "request body retries too many times raises error" do
    req =
      %Cartel.Request{
        method: :get,
        url: "http://localhost",
        headers: [],
        body: "",
        params: %{},
        options: [max_tries: 3]
      }

    expect(:hackney, :request, [{
      [req.method, req.url, req.headers, req.body, []],
      {:ok, 429, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert_raise Cartel.Error, "\"too many tries [3 of 3]\"", fn ->
      ExampleRetry.get!("localhost", [], %{}, max_tries: 3)
    end

    assert validate :hackney
  end

  test "request raises error tuple" do
    reason = {:closed, "Something happened"}
    expect(:hackney, :request, 5, {:error, reason})

    assert_raise Cartel.Error, "{:closed, \"Something happened\"}", fn ->
      Cartel.get!("http://localhost")
    end

    assert Cartel.get("http://localhost") == {:error, %Cartel.Error{reason: reason}}

    assert validate :hackney
  end

  test "passing connect_timeout option" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: [timeout: 12345]
      }

    expect(:hackney, :request, [{
      [req.method, req.url, req.headers, req.body, [{:connect_timeout, 12345}]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body", [], %{}, timeout: 12345) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "passing recv_timeout option" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: [recv_timeout: 12345]
      }

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", [{:recv_timeout, 12345}]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body", [], %{}, recv_timeout: 12345) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "passing proxy option" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: [proxy: "proxy"]
      }

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", [proxy: "proxy"]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body", [], %{}, proxy: "proxy") ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "passing proxy option with proxy_auth" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: [proxy: "proxy", proxy_auth: {"username", "password"}]
      }

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", [proxy_auth: {"username", "password"}, proxy: "proxy"]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body", [], %{}, [proxy: "proxy", proxy_auth: {"username", "password"}]) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "having http_proxy env variable set on http requests" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: []
      }

    expect(System, :get_env, [{["HTTP_PROXY"], "proxy"}])

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", [proxy: "proxy"]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body") ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate(:hackney)
  end

  test "having https_proxy env variable set on https requests" do
    req =
      %Cartel.Request{
        method: :post,
        url: "https://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: []
      }

    expect(System, :get_env, [{["HTTPS_PROXY"], "proxy"}])

    expect(:hackney, :request, [{
      [:post, "https://localhost", [], "body", [proxy: "proxy"]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("https://localhost", "body") ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate(:hackney)
  end

  test "having https_proxy env variable set on http requests" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: []
      }

    expect(System, :get_env, [
      {["HTTPS_PROXY"], "proxy"},
      {["HTTP_PROXY"], nil},
      {["http_proxy"], nil}
    ])

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", []],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body") ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate(:hackney)
  end

  test "passing ssl option" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: [ssl: [certfile: "certs/client.crt"]]
      }

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", [ssl_options: [certfile: "certs/client.crt"]]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body", [], %{}, ssl: [certfile: "certs/client.crt"]) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "passing follow_redirect option" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: [follow_redirect: true]
      }

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", [follow_redirect: true]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body", [], %{}, follow_redirect: true) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end

  test "passing max_redirect option" do
    req =
      %Cartel.Request{
        method: :post,
        url: "http://localhost",
        headers: [],
        body: "body",
        params: %{},
        options: [max_redirect: 2]
      }

    expect(:hackney, :request, [{
      [:post, "http://localhost", [], "body", [max_redirect: 2]],
      {:ok, 200, "headers", :client}
    }])

    expect(:hackney, :body, 1, {:ok, "response"})

    assert Cartel.post!("localhost", "body", [], %{}, max_redirect: 2) ==
      %Cartel.Response{
        status_code: 200,
        headers: "headers",
        body: "response",
        request: req
      }

    assert validate :hackney
  end
end
