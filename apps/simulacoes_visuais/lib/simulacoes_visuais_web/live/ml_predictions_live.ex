defmodule SimulacoesVisuaisWeb.MlPredictionsLive do
  @moduledoc """
  Lista predições persistidas por pipelines ML (artigo 15).
  """
  use SimulacoesVisuaisWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {preds, tsdb?} = load_predictions()

    {:ok,
     assign(socket,
       predictions: preds,
       tsdb_enabled: tsdb?
     )}
  end

  defp load_predictions do
    tsdb? = Application.get_env(:simulacoes_visuais, :tsdb_enabled, false)

    preds =
      if tsdb? do
        SimulacoesVisuais.MlPredictions.list_recent(100)
      else
        []
      end

    {preds, tsdb?}
  end

  @impl true
  def handle_event("refresh", _, socket) do
    {preds, tsdb?} = load_predictions()
    {:noreply, assign(socket, predictions: preds, tsdb_enabled: tsdb?)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path="/smart-brewery/ml-predictions">
      <div class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h1 class="text-xl font-semibold text-base-content">Predições ML</h1>
          <button
            id="ml-predictions-refresh"
            type="button"
            phx-click="refresh"
            class="btn btn-sm btn-outline rounded-lg"
          >
            Atualizar
          </button>
        </div>

        <p class="text-sm text-base-content/70 leading-relaxed">
          Registros persistidos na base de séries temporais (<.tech_term
            term={:tsdb}
            aria_describedby_glossary
            show_glossary_link
          />),
          tabela <code class="text-xs bg-base-200 px-1 rounded">ml_predictions</code>.
          Importação:
          <code class="text-xs bg-base-200 px-1 rounded">mix import.ml.predictions --file …</code>
          (ou <code class="text-xs bg-base-200 px-1 rounded">mix simulacoes_visuais.ml_import_predictions</code>).
          A flag de configuração <code class="text-xs bg-base-200 px-1 rounded">:tsdb_enabled</code>
          ativa o armazenamento TSDB.
        </p>

        <%= if not @tsdb_enabled do %>
          <p class="text-sm text-warning">
            <.tech_term term={:tsdb} text="TSDB" /> desabilitado — ligue
            <code class="text-xs">:tsdb_enabled</code>
            para listar predições.
          </p>
        <% end %>

        <div
          id="ml-predictions-table"
          class="overflow-x-auto rounded-xl border border-base-200 bg-base-100 shadow-sm"
        >
          <table class="table table-sm">
            <thead>
              <tr>
                <th scope="col">
                  <.tech_term term={:timestamp_utc} aria_describedby_glossary />
                </th>
                <th scope="col">
                  <.tech_term term={:modelo_ml} aria_describedby_glossary />
                </th>
                <th scope="col">
                  <.tech_term term={:alvo_ml} aria_describedby_glossary />
                </th>
                <th scope="col">
                  <.tech_term term={:valor_predicao} aria_describedby_glossary />
                </th>
              </tr>
            </thead>
            <tbody>
              <%= for p <- @predictions do %>
                <tr id={"ml-pred-row-#{p.id}"}>
                  <td class="whitespace-nowrap font-mono text-xs">{format_ts(p.ts)}</td>
                  <td>{p.model_name}</td>
                  <td>{p.target_name || "—"}</td>
                  <td>{format_float(p.value_float)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%= if @tsdb_enabled and @predictions == [] do %>
          <p class="text-sm text-base-content/60">Nenhuma predição importada ainda.</p>
        <% end %>

        <.glossary_section terms={SimulacoesVisuaisWeb.TechGlossary.terms_for(:ml_predictions)} />
      </div>
    </Layouts.app>
    """
  end

  defp format_ts(nil), do: "—"

  defp format_ts(%DateTime{} = dt) do
    dt |> DateTime.truncate(:second) |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_float(nil), do: "—"
  defp format_float(f) when is_float(f), do: to_string(Float.round(f, 4))
end
