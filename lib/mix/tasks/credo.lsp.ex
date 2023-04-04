defmodule Mix.Tasks.Credo.Lsp do
  @moduledoc """
  Starts the LSP server.

  The LSP server can be used to show Credo diagnostics in text editors such as Visual Studio Code, Vim/Neovim, and Emacs, and
  is generally made available through an editor extension.

  ## Usage

  ```bash
  $ mix credo.lsp
  ```
  """
  use Mix.Task

  alias Credo.Lsp

  @shortdoc "Starts the LSP server"

  @doc false
  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: [stdio: :boolean, port: :integer])
    System.no_halt(true)
    {:ok, _} = Application.ensure_all_started(:credo)
    GenServer.call(Credo.CLI.Output.Shell, {:suppress_output, true})

    buffer_opts =
      cond do
        opts[:stdio] -> []
        is_integer(opts[:port]) ->
          IO.puts "Starting on port #{opts[:port]}"
          [communication: {GenLSP.Communication.TCP, [port: opts[:port]]}]
        true -> raise "Unknown option"
      end

    {:ok, buffer} = GenLSP.Buffer.start_link(buffer_opts)
    {:ok, cache} = Lsp.Cache.start_link([])
    {:ok, _} = Lsp.start_link(buffer: buffer, cache: cache)
  end
end
