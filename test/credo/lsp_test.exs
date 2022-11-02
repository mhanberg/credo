defmodule Credo.LspTest do
  use ExUnit.Case, async: false

  import GenLSP.Test
  alias Credo.Lsp

  setup do
    cache = start_supervised!(Credo.Lsp.Cache)
    server = server(Lsp, cache: cache)
    client = client(server)

    [server: server, client: client]
  end

  test "can start the LSP server", %{server: server} do
    assert alive?(server)
  end

  test "can initialize the server", %{client: client} do
    assert :ok ==
             request(client, %{
               method: "initialize",
               id: 1,
               jsonrpc: "2.0",
               params: %{capabilities: %{}}
             })

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

  test "publishes diagnostics once the client has initialized", %{client: client} do
    assert :ok == notify(client, %{method: "initialized", jsonrpc: "2.0", params: %{}})

    assert_notification("window/logMessage", %{
      "message" => "[Credo] LSP Initialized!",
      "type" => 4
    })

    assert_notification("textDocument/publishDiagnostics", %{
      "params" => %{
        "uri" => "file://" <> _,
        "diagnostics" => diagnostics
      }
    })

    dbg(diagnostics)

    assert false
  end
end
