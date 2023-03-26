defmodule Credo.LspTest do
  use ExUnit.Case, async: false

  import GenLSP.Test
  alias Credo.Lsp

  setup do
    cache = start_supervised!(Credo.Lsp.Cache)
    server = server(Lsp, cache: cache)
    client = client(server)

    cwd = File.cwd!()

    root_path = Path.join(cwd, "test/fixtures/lsp")

    assert :ok ==
             request(client, %{
               method: "initialize",
               id: 1,
               jsonrpc: "2.0",
               params: %{capabilities: %{}, rootUri: "file://#{root_path}"}
             })

    [server: server, client: client, cwd: cwd]
  end

  test "can start the LSP server", %{server: server} do
    assert alive?(server)
  end

  test "can initialize the server" do
    assert_result(1, %{
      "capabilities" => %{
        "textDocumentSync" => %{
          "openClose" => true,
          "save" => %{
            "includeText" => true
          },
          "change" => 1
        }
      },
      "serverInfo" => %{"name" => "Credo"}
    })
  end

  test "publishes diagnostics once the client has initialized", %{client: client, cwd: cwd} do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_notification("window/logMessage", %{
      "message" => "[Credo] LSP Initialized!",
      "type" => 4
    })

    for file <- ["foo.ex", "bar.ex"] do
      uri =
        to_string(%URI{
          host: "",
          scheme: "file",
          path: Path.join([cwd, "test/fixtures/lsp", file])
        })

      assert_notification(
        "textDocument/publishDiagnostics",
        %{"uri" => ^uri, "diagnostics" => [%{"severity" => 4}]},
        500
      )
    end
  end
end
