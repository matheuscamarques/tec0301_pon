/**
 * LiveView hook: ECharts para gráfico de telemetria por FBE (artigo 07 §7.1).
 * Recebe dados via push_event("chart_data", payload). Se o elemento tiver data-fbe-id,
 * payload é um mapa { "1" => { series_name, labels, values }, ... }; senão payload único.
 */
const ChartHook = {
  mounted() {
    const container = this.el.querySelector("[data-chart-container]") || this.el
    this._fbeId = this.el.dataset.fbeId ?? null
    if (typeof window.echarts === "undefined") {
      container.innerHTML = "<p class=\"text-sm text-base-content/60 p-4\">ECharts carregando…</p>"
      return
    }
    this.chart = window.echarts.init(container, null, { renderer: "canvas" })
    this.chart.setOption({
      grid: { left: 40, right: 16, top: 16, bottom: 24 },
      xAxis: { type: "category", data: [] },
      yAxis: { type: "value" },
      series: [{ type: "line", data: [], smooth: true }]
    })
    this.handleEvent("chart_data", (payload) => {
      if (!this.chart) return
      const data = this._fbeId != null && payload[this._fbeId] != null
        ? payload[this._fbeId]
        : (payload.series_name != null ? payload : null)
      if (!data) return
      const labels = data.labels || []
      const values = data.values || []
      const seriesName = data.series_name || "Telemetria"
      this.chart.setOption({
        xAxis: { data: labels },
        series: [{ name: seriesName, data: values }]
      })
    })
  },
  destroyed() {
    if (this.chart) this.chart.dispose()
  }
}

export default ChartHook
