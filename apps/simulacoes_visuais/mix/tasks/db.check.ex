defmodule Mix.Tasks.Db.Check do
  @shortdoc "Checks that PostgreSQL is reachable before ecto.create/ecto.migrate"
  @moduledoc """
  Tries to open a TCP connection to the configured Repo host:port.
  On connection refused, prints a clear message and exits with status 1.
  Used by the ecto.create alias so users see: "Start the database with: docker compose up -d".
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    repo_config = Application.get_env(:simulacoes_visuais, SimulacoesVisuais.Repo) || []

    {host, port} =
      case repo_config[:url] do
        nil ->
          {
            repo_config[:hostname] || "localhost",
            repo_config[:port] || 5432
          }

        url ->
          uri = URI.parse(url)
          {uri.host || "localhost", uri.port || 5432}
      end

    host_charlist = String.to_charlist(host)

    case :gen_tcp.connect(host_charlist, port, [], 3_000) do
      {:ok, sock} ->
        :gen_tcp.close(sock)
        :ok

      {:error, :econnrefused} ->
        Mix.raise("""
        Database not reachable at #{host}:#{port} (connection refused).
        Start PostgreSQL first, e.g. from project root:
          docker compose up -d
        Then run: mix ecto.create && mix ecto.migrate
        See docs/docker.md for details.
        """)
    end
  end
end
