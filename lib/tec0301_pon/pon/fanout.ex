defmodule Tec0301Pon.PON.Fanout do
  @moduledoc """
  Atualiza vários fatos sem `Registry.dispatch` individual e envia **uma** mensagem
  `{:notificacoes_lote, mapa}` por processo inscrito (coalescência no barramento).

  Apenas fatos cujo valor **mudou** entram no mapa notificado.
  """
  @pubsub Tec0301Pon.PON.PubSub

  @doc """
  Para cada par `fato => valor`, aplica atualização silenciosa (síncrona) e notifica
  inscritos com um único `{:notificacoes_lote, %{...}}` contendo só alterações efetivas.
  """
  def atualizar_lote(updates) when is_map(updates) do
    if map_size(updates) == 0 do
      :ok
    else
      pairs = Map.to_list(updates)

      changed =
        if length(pairs) <= 4 do
          apply_updates_sequential(pairs, %{})
        else
          max_c =
            pairs
            |> length()
            |> min(max(1, System.schedulers_online()) * 2)
            |> min(32)

          pairs
          |> Task.async_stream(
            fn {nome, val} ->
              case GenServer.call(nome, {:atualizar_sem_dispatch, val}, 5_000) do
                :changed -> {nome, val}
                :unchanged -> nil
              end
            end,
            max_concurrency: max_c,
            ordered: false,
            timeout: 15_000,
            on_timeout: :kill_task
          )
          |> Enum.reduce(%{}, &merge_async_stream_chunk/2)
        end

      if map_size(changed) > 0 do
        notify_lote(changed)
      end

      :ok
    end
  end

  defp apply_updates_sequential([], acc), do: acc

  defp apply_updates_sequential([{nome, val} | rest], acc) do
    acc =
      case GenServer.call(nome, {:atualizar_sem_dispatch, val}, 5_000) do
        :changed -> Map.put(acc, nome, val)
        :unchanged -> acc
      end

    apply_updates_sequential(rest, acc)
  end

  defp merge_async_stream_chunk({:ok, nil}, acc), do: acc

  defp merge_async_stream_chunk({:ok, {n, v}}, acc), do: Map.put(acc, n, v)

  defp merge_async_stream_chunk({:exit, reason}, _acc) do
    raise "Fanout.atualizar_lote task failed: #{inspect(reason)}"
  end

  @doc false
  def __test_merge_async_stream_chunk(result, acc \\ %{}),
    do: merge_async_stream_chunk(result, acc)

  defp notify_lote(changed) when is_map(changed) do
    pids =
      changed
      |> Map.keys()
      |> Enum.flat_map(fn key ->
        Registry.lookup(@pubsub, key)
        |> Enum.map(fn {pid, _} -> pid end)
      end)
      |> Enum.uniq()

    msg = {:notificacoes_lote, changed}

    Enum.each(pids, fn pid -> send(pid, msg) end)
  end
end
