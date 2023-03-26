defmodule Credo.Lsp do
  @moduledoc """
  LSP implementation for Credo.
  """
  use GenLSP

  alias GenLSP.Enumerations.TextDocumentSyncKind

  alias GenLSP.Notifications.{
    Exit,
    Initialized,
    TextDocumentDidChange,
    TextDocumentDidClose,
    TextDocumentDidOpen,
    TextDocumentDidSave
  }

  alias GenLSP.Requests.{Initialize, Shutdown}

  alias GenLSP.Structures.{
    InitializeParams,
    InitializeResult,
    SaveOptions,
    ServerCapabilities,
    TextDocumentSyncOptions
  }

  alias Credo.Lsp.Cache, as: Diagnostics

  def start_link(args) do
    GenLSP.start_link(__MODULE__, args, [])
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
         }
       },
       server_info: %{name: "Credo"}
     }, assign(lsp, root_uri: root_uri)}
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
