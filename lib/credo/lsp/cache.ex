defmodule Credo.Lsp.Cache do
  @moduledoc """
  Cache for Credo diagnostics.
  """
  use Agent

  alias GenLSP.Structures.{
    Diagnostic,
    Position,
    PublishDiagnosticsParams,
    Range
  }

  alias GenLSP.Notifications.TextDocumentPublishDiagnostics

  def start_link(_) do
    Agent.start_link(fn -> Map.new() end)
  end

  def refresh(cache, lsp) do
    dir = URI.parse(lsp.assigns.root_uri).path

    issues = Credo.Execution.get_issues(Credo.run(["--strict", "--all", "#{dir}/**/*.ex"]))

    GenLSP.log(lsp, :info, "[Credo] Found #{Enum.count(issues)} issues")

    for issue <- issues do
      diagnostic = %Diagnostic{
        range: %Range{
          start: %Position{line: issue.line_no - 1, character: issue.column || 0},
          end: %Position{line: issue.line_no, character: 0}
        },
        severity: category_to_severity(issue.category),
        message: """
        #{issue.message}

        ## Explanation

        #{issue.check.explanations()[:check]}
        """
      }

      put(cache, Path.absname(issue.filename), diagnostic)
    end
  end

  def get(cache) do
    Agent.get(cache, & &1)
  end

  def put(cache, filename, diagnostic) do
    Agent.update(cache, fn cache ->
      Map.update(cache, Path.absname(filename), [diagnostic], fn v ->
        [diagnostic | v]
      end)
    end)
  end

  def clear(cache) do
    Agent.update(cache, fn cache ->
      for {k, _} <- cache, into: Map.new() do
        {k, []}
      end
    end)
  end

  def publish(cache, lsp) do
    for {file, diagnostics} <- get(cache) do
      GenLSP.notify(lsp, %TextDocumentPublishDiagnostics{
        params: %PublishDiagnosticsParams{
          uri: "file://#{file}",
          diagnostics: diagnostics
        }
      })
    end
  end

  def category_to_severity(:refactor), do: 1
  def category_to_severity(:warning), do: 2
  def category_to_severity(:design), do: 3
  def category_to_severity(:consistency), do: 4
  def category_to_severity(:readability), do: 4
end
