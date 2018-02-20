defmodule CartelTest do
  use ExUnit.Case, async: true
  import PathHelpers

  setup_all do
    {:ok, _} = :application.ensure_all_started(:httparrot)
    :ok
  end

  test "get" do
    assert_response Cartel.get("localhost:8080/deny"), fn(response) ->
      assert :erlang.size(response.body) == 197
    end
  end

  test "get with params" do
    resp = Cartel.get("localhost:8080/get", [], %{foo: "bar", baz: "bong"})
    assert_response resp, fn(response) ->
      args = JSX.decode!(response.body)["args"]
      assert args["foo"] == "bar"
      assert args["baz"] == "bong"
      assert (args |> Map.keys |> length) == 2
    end
  end

  test "get with params in url and params" do
    resp = Cartel.get("localhost:8080/get?bar=zing&foo=first", [], [{"foo", "second"}, {"baz", "bong"}])
    assert_response resp, fn(response) ->
      args = JSX.decode!(response.body)["args"]
      assert args["foo"] == ["first", "second"]
      assert args["baz"] == "bong"
      assert args["bar"] == "zing"
      assert (args |> Map.keys |> length) == 3
    end
  end

  test "head" do
    assert_response Cartel.head("localhost:8080/get"), fn(response) ->
      assert response.body == ""
    end
  end

  test "post charlist body" do
    assert_response Cartel.post("localhost:8080/post", 'test')
  end

  test "post binary body" do
    { :ok, file } = File.read(fixture_path("image.png"))

    assert_response Cartel.post("localhost:8080/post", file)
  end

  test "post form data" do
    assert_response Cartel.post("localhost:8080/post", {:form, [key: "value"]}, %{"Content-type" => "application/x-www-form-urlencoded"}), fn(response) ->
      Regex.match?(~r/"key".*"value"/, response.body)
    end
  end

  test "put" do
    assert_response Cartel.put("localhost:8080/put", "test")
  end

  test "put without body" do
    assert_response Cartel.put("localhost:8080/put")
  end

  test "patch" do
    assert_response Cartel.patch("localhost:8080/patch", "test")
  end

  test "delete" do
    assert_response Cartel.delete("localhost:8080/delete")
  end

  test "options" do
    assert_response Cartel.options("localhost:8080/get"), fn(response) ->
      assert get_header(response.headers, "content-length") == "0"
      assert is_binary(get_header(response.headers, "allow"))
    end
  end

  test "option follow redirect absolute url" do
    assert_response Cartel.get("http://localhost:8080/redirect-to?url=http%3A%2F%2Flocalhost:8080%2Fget", [], %{}, [follow_redirect: true])
  end

  test "option follow redirect relative url" do
    assert_response Cartel.get("http://localhost:8080/relative-redirect/1", [], %{}, [follow_redirect: true])
  end

  test "basic_auth hackney option" do
    hackney = [basic_auth: {"user", "pass"}]
    assert_response Cartel.get("http://localhost:8080/basic-auth/user/pass", [], %{}, [hackney: hackney])
  end

  test "explicit http scheme" do
    assert_response Cartel.head("http://localhost:8080/get")
  end

  test "https scheme" do
    httparrot_priv_dir = :code.priv_dir(:httparrot)
    cacert_file = "#{httparrot_priv_dir}/ssl/server-ca.crt"
    cert_file = "#{httparrot_priv_dir}/ssl/server.crt"
    key_file =  "#{httparrot_priv_dir}/ssl/server.key"

    assert_response Cartel.get("https://localhost:8433/get", [], %{}, ssl: [cacertfile: cacert_file, keyfile: key_file, certfile: cert_file])
  end

  test "http+unix scheme" do
    if Application.get_env(:httparrot, :unix_socket, false) do
      case {HTTParrot.unix_socket_supported?, Application.fetch_env(:httparrot, :socket_path)} do
        {true, {:ok, path}} ->
          path = URI.encode_www_form(path)
          assert_response Cartel.get("http+unix://#{path}/get")
        _ -> :ok
      end
    end
  end

  test "char list URL" do
    assert_response Cartel.head('localhost:8080/get')
  end

  test "request headers as a map" do
    map_header = %{"X-Header" => "X-Value"}
    assert Cartel.get!("localhost:8080/get", map_header).body =~ "X-Value"
  end

  test "cached request" do
    if_modified = %{"If-Modified-Since" => "Tue, 11 Dec 2012 10:10:24 GMT"}
    response = Cartel.get!("localhost:8080/cache", if_modified)
    assert %Cartel.Response{status_code: 304, body: ""} = response
  end

  test "send cookies" do
    response = Cartel.get!("localhost:8080/cookies", %{}, %{}, hackney: [cookie: ["foo=1; bar=2"]])
    assert response.body |> String.replace( ~r/\s|\r?\n/, "") |> String.replace(~r/\"/, "'") |> JSX.decode! == %{"cookies" => %{"foo" => "1", "bar" => "2"}}
  end

  test "receive cookies" do
    response = Cartel.get!("localhost:8080/cookies/set?foo=1&bar=2")
    has_foo = Enum.member?(response.headers, {"set-cookie", "foo=1; Version=1; Path=/"})
    has_bar = Enum.member?(response.headers, {"set-cookie", "bar=2; Version=1; Path=/"})
    assert has_foo and has_bar
  end

  test "exception" do
    assert Cartel.get("localhost:1") == {:error, %Cartel.Error{reason: :econnrefused}}
    assert_raise Cartel.Error, ":econnrefused", fn ->
      Cartel.get!("localhost:1")
    end
  end

  test "asynchronous request" do
    {:ok, %Cartel.AsyncResponse{id: id}} = Cartel.get("localhost:8080/get", [], %{}, [stream_to: self()])

    assert_receive %Cartel.AsyncStatus{ id: ^id, code: 200 }, 1_000
    assert_receive %Cartel.AsyncHeaders{ id: ^id, headers: headers }, 1_000
    assert_receive %Cartel.AsyncChunk{ id: ^id, chunk: _chunk }, 1_000
    assert_receive %Cartel.AsyncEnd{ id: ^id }, 1_000
    assert is_list(headers)
  end

  test "asynchronous request with explicit streaming using [async: :once]" do
    {:ok, resp = %Cartel.AsyncResponse{id: id}} = Cartel.get("localhost:8080/get", [], %{}, [stream_to: self(), async: :once])

    assert_receive %Cartel.AsyncStatus{ id: ^id, code: 200 }, 100

    refute_receive %Cartel.AsyncHeaders{ id: ^id, headers: _headers }, 100
    {:ok, ^resp} = Cartel.stream_next(resp)
    assert_receive %Cartel.AsyncHeaders{ id: ^id, headers: headers }, 100

    refute_receive %Cartel.AsyncChunk{ id: ^id, chunk: _chunk }, 100
    {:ok, ^resp} = Cartel.stream_next(resp)
    assert_receive %Cartel.AsyncChunk{ id: ^id, chunk: _chunk }, 100

    refute_receive %Cartel.AsyncEnd{ id: ^id }, 100
    {:ok, ^resp} = Cartel.stream_next(resp)
    assert_receive %Cartel.AsyncEnd{ id: ^id }, 100

    assert is_list(headers)
  end

  test "asynchronous redirected get request" do
    {:ok, %Cartel.AsyncResponse{id: id}} = Cartel.get("localhost:8080/redirect/2", [], %{}, [stream_to: self(), hackney: [follow_redirect: true]])

    assert_receive %Cartel.AsyncRedirect{ id: ^id, to: to, headers: headers }, 1_000
    assert to == "http://localhost:8080/redirect/1"
    assert is_list(headers)
  end

  test "multipart upload" do
    response = Cartel.post("localhost:8080/post", {:multipart, [{:file, "test/test_helper.exs"}, {"name", "value"}]})
    assert_response(response)
  end

  test "post streaming body" do
    expected = %{"some" => "bytes"}
    enumerable = JSX.encode!(expected) |> String.split("")
    headers = %{"Content-type" => "application/json"}
    response = Cartel.post("localhost:8080/post", {:stream, enumerable}, headers)
    assert_response response
    {:ok, %Cartel.Response{body: body}} = response

    assert JSX.decode!(body)["json"] == expected
  end

  defp assert_response({:ok, response}, function \\ nil) do
    assert is_list(response.headers)
    assert response.status_code == 200
    assert is_binary(response.body)

    unless function == nil, do: function.(response)
  end

  defp get_header(headers, key) do
    headers
    |> Enum.filter(fn({k, _}) -> k == key end)
    |> hd
    |> elem(1)
  end
end