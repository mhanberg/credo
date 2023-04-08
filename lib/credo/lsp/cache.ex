defmodule Credo.Lsp.Cache do
  @moduledoc """
  Cache for Credo diagnostics.
  """
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> Map.new() end)
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
end
