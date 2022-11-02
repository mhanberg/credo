defmodule Mix.Tasks.Credo.Lsp do
  use Mix.Task

  alias Credo.Lsp

  @shortdoc "A placeholder shortdoc for mix "
  @moduledoc @shortdoc

  @doc false
  def run(_argv) do
    System.no_halt(true)
    {:ok, _} = Application.ensure_all_started(:credo)
    GenServer.call(Credo.CLI.Output.Shell, {:suppress_output, true})

    {:ok, buffer} = GenLSP.Buffer.start_link([])
    {:ok, cache} = Lsp.Cache.start_link([])
    {:ok, _} = Lsp.start_link(buffer: buffer, cache: cache)
  end
end
