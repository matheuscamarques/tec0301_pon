defmodule SimulacoesVisuais.CriticalLogHandler do
  @moduledoc """
  Registra um segundo handler OTP (`:logger_std_h` em modo arquivo) para gravar logs
  a partir de um nível mínimo (default `:error`: `error`, `critical`, `alert`, `emergency`).

  Chamado em `Application.start/2` após o supervisor subir. Configuração:
  `Application.get_env(:simulacoes_visuais, :critical_log_file)`.

  * **Caminho do arquivo**: variável de ambiente `CRITICAL_LOG_FILE`, ou
    `Application.app_dir(:simulacoes_visuais, "priv/log/critical.log")` (em dev costuma ser
    `_build/dev/lib/simulacoes_visuais-<vsn>/priv/log/critical.log`).
  * **Desligar**: `enabled: false` na config ou `CRITICAL_LOG_FILE` vazio.
  * **Só `critical` e acima** (menos linhas): `level: :critical` na config.
  """

  @handler_id :simulacoes_visuais_critical_file

  @doc false
  def attach do
    opts = Application.get_env(:simulacoes_visuais, :critical_log_file) || []

    cond do
      Keyword.get(opts, :enabled, true) == false ->
        :ok

      System.get_env("CRITICAL_LOG_FILE") == "" ->
        :ok

      true ->
        do_attach(opts)
    end
  end

  defp do_attach(opts) do
    path =
      case System.get_env("CRITICAL_LOG_FILE") do
        nil -> default_log_path(opts)
        "" -> nil
        p -> p
      end

    if is_nil(path) or path == "" do
      :ok
    else
      path = Path.expand(path)
      File.mkdir_p!(Path.dirname(path))

      file_cl = String.to_charlist(path)
      min_level = Keyword.get(opts, :level, :error)
      max_bytes = Keyword.get(opts, :max_no_bytes, 10_485_760)
      max_files = Keyword.get(opts, :max_no_files, 5)

      format = Keyword.get(opts, :format, "$time $metadata[$level] $message\n")
      metadata = Keyword.get(opts, :metadata, [:request_id])
      formatter = Logger.Formatter.new(format: format, metadata: metadata)

      handler_config =
        [
          module: :logger_std_h,
          level: min_level,
          formatter: formatter,
          filters: [remote_gl: {&:logger_filters.remote_gl/2, :stop}],
          filter_default: :log,
          config: %{
            type: :file,
            file: file_cl,
            max_no_bytes: max_bytes,
            max_no_files: max_files
          }
        ]
        |> Map.new()

      case :logger.add_handler(@handler_id, handler_config.module, handler_config) do
        :ok ->
          :ok

        {:error, {:already_exists, _}} ->
          :ok

        {:error, reason} ->
          IO.puts(:stderr, "[SimulacoesVisuais] CriticalLogHandler: #{inspect(reason)}")
      end
    end
  end

  defp default_log_path(opts) do
    case Keyword.fetch(opts, :path) do
      {:ok, p} when is_binary(p) and p != "" ->
        Path.expand(p)

      _ ->
        Application.app_dir(:simulacoes_visuais, "priv/log/critical.log")
    end
  end
end
