defmodule SimulacoesVisuais.ML.Features do
  @moduledoc """
  Montagem de tensores para treino a partir de telemetria/OEE exportados.
  """

  @doc """
  Constrói matriz de features por minuto (FBE_08, valores float) e alinha cada snapshot OEE
  ao último minuto completo ≤ `ts` do OEE.

  Retorna `{:ok, {x, y, fact_names}}` com `x` `{n, k}`, `y` `{n}` ou `{:error, reason}`.
  """
  def oee_supervised_dataset(telemetry_rows, oee_rows, opts \\ []) when is_list(telemetry_rows) do
    prefix = Keyword.get(opts, :fact_prefix, "fbe_08_")

    tel =
      Enum.filter(telemetry_rows, fn row ->
        String.starts_with?(row.fact_name, prefix) and is_number(row.value_float)
      end)

    if tel == [] or oee_rows == [] do
      {:error, :insufficient_data}
    else
      {wide, fact_names} = pivot_minute(tel)

      if map_size(wide) == 0 do
        {:error, :insufficient_data}
      else
        oee_sorted = Enum.sort_by(oee_rows, & &1.ts, DateTime)
        minute_keys = wide |> Map.keys() |> Enum.sort(DateTime)
        build_oee_pairs(oee_sorted, wide, fact_names, minute_keys)
      end
    end
  end

  defp build_oee_pairs(oee_sorted, wide, fact_names, minute_keys) do
    pairs =
      Enum.flat_map(oee_sorted, fn %{ts: oee_ts, oee_pct: y} ->
        oee_min = truncate_minute(oee_ts)

        case last_wide_at_or_before(wide, minute_keys, oee_min) do
          nil -> []
          vec -> [{vec, y}]
        end
      end)

    case pairs do
      [] ->
        {:error, :insufficient_data}

      _ ->
        {xs, ys} = Enum.unzip(pairs)
        x = Nx.stack(xs)
        y = Nx.tensor(ys, type: :f32)
        {:ok, {x, y, fact_names}}
    end
  end

  defp truncate_minute(%DateTime{} = dt) do
    %{dt | second: 0, microsecond: {0, 6}}
  end

  defp last_wide_at_or_before(wide, minute_keys, oee_min) do
    minute_keys
    |> Enum.filter(&(DateTime.compare(&1, oee_min) != :gt))
    |> List.last()
    |> case do
      nil -> nil
      k -> Map.fetch!(wide, k)
    end
  end

  defp pivot_minute(tel) do
    fact_names =
      tel |> Enum.map(& &1.fact_name) |> Enum.uniq() |> Enum.sort()

    all_minutes =
      tel
      |> Enum.map(fn r -> truncate_minute(r.ts) end)
      |> Enum.uniq()
      |> Enum.sort(DateTime)

    by_minute = Enum.group_by(tel, fn r -> truncate_minute(r.ts) end)

    {wide, _} =
      Enum.reduce(all_minutes, {%{}, %{}}, fn minute, {wacc, carry} ->
        rows = Map.get(by_minute, minute, [])

        carry2 =
          Enum.reduce(rows, carry, fn %{fact_name: f, value_float: v}, c ->
            Map.put(c, f, v)
          end)

        vec =
          Enum.map(fact_names, fn f ->
            Map.get(carry2, f)
          end)

        if Enum.any?(vec, &is_nil/1) do
          {wacc, carry2}
        else
          {Map.put(wacc, minute, Nx.tensor(vec, type: :f32)), carry2}
        end
      end)

    {wide, fact_names}
  end

  @doc """
  Janelas deslizantes para fermentação: fatos `fbe_06_*` contínuos, tensor `{n, seq_len * n_feat}` e alvo `{n, n_feat}` (próximo passo).
  """
  def fermentation_windows(telemetry_rows, opts \\ []) do
    facts =
      Keyword.get(opts, :facts, [
        "fbe_06_internal_temp",
        "fbe_06_gravity_brix",
        "fbe_06_ph",
        "fbe_06_co2_exhaust_flow",
        "fbe_06_pressure"
      ])

    seq_len = Keyword.get(opts, :seq_len, 8)

    sub =
      Enum.filter(telemetry_rows, fn r ->
        r.fact_name in facts and is_number(r.value_float)
      end)

    by_min =
      sub
      |> Enum.group_by(fn r -> truncate_minute(r.ts) end)
      |> Enum.map(fn {k, rows} ->
        m =
          rows
          |> Enum.map(fn x -> {x.fact_name, x.value_float} end)
          |> Map.new()

        if Enum.all?(facts, &Map.has_key?(m, &1)) do
          vec = Enum.map(facts, &Map.fetch!(m, &1))
          {k, Nx.tensor(vec, type: :f32)}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&elem(&1, 0), DateTime)

    case by_min do
      [] ->
        {:error, :insufficient_data}

      vecs when length(vecs) < seq_len + 2 ->
        {:error, :insufficient_data}

      vecs ->
        tensors = Enum.map(vecs, &elem(&1, 1))
        n_feat = length(facts)
        flat_len = seq_len * n_feat

        {xs, ys} =
          Enum.reduce(seq_len..(length(tensors) - 1)//1, {[], []}, fn i, {ax, ay} ->
            window = Enum.slice(tensors, (i - seq_len)..(i - 1)//1)
            flat = window |> Nx.stack() |> Nx.flatten()
            tgt = Enum.at(tensors, i)
            {[flat | ax], [tgt | ay]}
          end)

        x = Nx.stack(Enum.reverse(xs))
        y = Nx.stack(Enum.reverse(ys))
        {:ok, {x, y, flat_len, n_feat}}
    end
  end

  @doc """
  Matriz multivariada FBE_01 (uma linha por minuto com todos os floats disponíveis).
  """
  def mill_matrix(telemetry_rows) do
    sub =
      Enum.filter(telemetry_rows, fn r ->
        String.starts_with?(r.fact_name, "fbe_01_") and is_number(r.value_float)
      end)

    fact_names = sub |> Enum.map(& &1.fact_name) |> Enum.uniq() |> Enum.sort()

    by_minute = Enum.group_by(sub, fn r -> truncate_minute(r.ts) end)

    rows =
      by_minute
      |> Enum.map(fn {_k, rows} ->
        m = Map.new(rows, &{&1.fact_name, &1.value_float})

        if Enum.all?(fact_names, &Map.has_key?(m, &1)) do
          Nx.tensor(Enum.map(fact_names, &Map.fetch!(m, &1)), type: :f32)
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case rows do
      [] -> {:error, :insufficient_data}
      rs -> {:ok, {Nx.stack(rs), fact_names}}
    end
  end
end
