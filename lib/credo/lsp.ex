defmodule Credo.Lsp do
  @moduledoc """
  LSP implementation for Credo.
  """
  use GenLSP

  alias GenLSP.Enumerations.{CodeActionKind, TextDocumentSyncKind}

  alias GenLSP.Notifications.{
    Exit,
    Initialized,
    TextDocumentDidChange,
    TextDocumentDidClose,
    TextDocumentDidOpen,
    TextDocumentDidSave
  }

  alias GenLSP.Requests.{Initialize, Shutdown, TextDocumentCodeAction}

  alias GenLSP.Structures.{
    CodeActionOptions,
    InitializeParams,
    InitializeResult,
    SaveOptions,
    ServerCapabilities,
    TextDocumentIdentifier,
    TextDocumentSyncOptions
  }

  alias Credo.Lsp.Cache, as: Diagnostics

  def start_link(args) do
    {args, opts} = Keyword.split(args, [:cache])

    GenLSP.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(lsp, args) do
    cache = Keyword.fetch!(args, :cache)

    {:ok, assign(lsp, exit_code: 1, cache: cache)}
  end

  @impl true
  def handle_request(%Initialize{params: %InitializeParams{root_uri: root_uri}}, lsp) do
    {:reply,
     %InitializeResult{
       capabilities: %ServerCapabilities{
         text_document_sync: %TextDocumentSyncOptions{
           open_close: true,
           save: %SaveOptions{include_text: true},
           change: TextDocumentSyncKind.full()
         },
         code_action_provider: %CodeActionOptions{code_action_kinds: [CodeActionKind.quick_fix()]}
       },
       server_info: %{name: "Credo"}
     }, assign(lsp, root_uri: root_uri)}
  end

  def handle_request(
        %TextDocumentCodeAction{
          params: %GenLSP.Structures.CodeActionParams{
            context: %GenLSP.Structures.CodeActionContext{diagnostics: diagnostics},
            text_document: %TextDocumentIdentifier{uri: uri}
          }
        },
        lsp
      ) do
    code_actions =
      for %GenLSP.Structures.Diagnostic{} = d <- diagnostics do
        check =
          d.data["check"]
          |> to_string()
          |> String.replace("Elixir.", "")

        position = %GenLSP.Structures.Position{
          line: d.range.start.line,
          character: 0
        }

        %GenLSP.Structures.CodeAction{
          title: "Disable #{check}",
          edit: %GenLSP.Structures.WorkspaceEdit{
            changes: %{
              uri => [
                %GenLSP.Structures.TextEdit{
                  new_text: "# credo:disable-for-next-line #{check}\n",
                  range: %GenLSP.Structures.Range{start: position, end: position}
                }
              ]
            }
          }
        }
      end

    {:reply, code_actions, lsp}
  end

  def handle_request(%Shutdown{}, lsp) do
    {:noreply, assign(lsp, exit_code: 0)}
  end

  @impl true
  def handle_notification(%Initialized{}, lsp) do
    GenLSP.log(lsp, :log, "[Credo] LSP Initialized!")
    Diagnostics.refresh(lsp.assigns.cache, lsp)
    Diagnostics.publish(lsp.assigns.cache, lsp)

    {:noreply, lsp}
  end

  def handle_notification(%TextDocumentDidSave{}, lsp) do
    Task.start_link(fn ->
      Diagnostics.clear(lsp.assigns.cache)
      Diagnostics.refresh(lsp.assigns.cache, lsp)
      Diagnostics.publish(lsp.assigns.cache, lsp)
    end)

    {:noreply, lsp}
  end

  def handle_notification(%TextDocumentDidChange{}, lsp) do
    Task.start_link(fn ->
      Diagnostics.clear(lsp.assigns.cache)
      Diagnostics.publish(lsp.assigns.cache, lsp)
    end)

    {:noreply, lsp}
  end

  def handle_notification(%note{}, lsp)
      when note in [TextDocumentDidOpen, TextDocumentDidClose] do
    {:noreply, lsp}
  end

  def handle_notification(%Exit{}, lsp) do
    System.halt(lsp.assigns.exit_code)

    {:noreply, lsp}
  end

  def handle_notification(_thing, lsp) do
    {:noreply, lsp}
  end
end
