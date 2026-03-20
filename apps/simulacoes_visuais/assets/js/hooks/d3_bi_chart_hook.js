/**
 * LiveView hook: D3 line charts for Smart Brewery BI (OEE multi-series, telemetry, CEP).
 * Payload JSON in data-payload; phx-update="ignore" on this element — attributes still patch.
 */
import * as d3 from "d3"

const SEMANTIC_COLORS = {
  primary: "--color-primary",
  secondary: "--color-secondary",
  accent: "--color-accent",
  success: "--color-success",
  warning: "--color-warning",
  info: "--color-info",
  neutral: "--color-neutral",
  "base-content": "--color-base-content",
  "base-100": "--color-base-100"
}

function resolveColor(token) {
  if (token == null || token === "") return "#888"
  const s = String(token).trim()
  if (s.startsWith("#") || s.startsWith("rgb") || s.startsWith("oklch")) return s
  const cssVar = SEMANTIC_COLORS[s] || SEMANTIC_COLORS.neutral
  const v = getComputedStyle(document.documentElement).getPropertyValue(cssVar).trim()
  return v || "#888"
}

function parsePayload(raw) {
  if (raw == null || raw === "") return null
  try {
    return JSON.parse(raw)
  } catch {
    return null
  }
}

function parseTime(t) {
  if (t == null) return null
  const d = typeof t === "string" ? d3.isoParse(t) : new Date(t)
  return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null
}

/** Ponto da série temporal mais próximo de t0 (array ordenado por .t). */
function nearestByTime(rows, t0) {
  if (!rows || rows.length === 0) return null
  if (rows.length === 1) return rows[0]
  if (t0 <= rows[0].t) return rows[0]
  const last = rows[rows.length - 1]
  if (t0 >= last.t) return last
  const i = d3.bisector((d) => d.t).left(rows, t0)
  const a = rows[i - 1]
  const b = rows[i]
  return t0 - a.t <= b.t - t0 ? a : b
}

function tooltipHtmlTimeRow(t) {
  return d3.timeFormat("%d/%m/%Y %H:%M")(t)
}

const fmtHover = d3.format(".4~g")

const D3BiChartHook = {
  mounted() {
    this._root = document.createElement("div")
    this._root.setAttribute("data-d3-root", "")
    this._root.className = "relative w-full h-full min-h-[11rem]"
    this.el.appendChild(this._root)

    this._ro = new ResizeObserver(() => this.draw())
    this._ro.observe(this.el)

    this._lastRaw = null
    this.draw()
  },

  updated() {
    const raw = this.el.dataset.payload ?? ""
    if (raw !== this._lastRaw) this.draw()
  },

  destroyed() {
    if (this._ro) {
      this._ro.disconnect()
      this._ro = null
    }
  },

  draw() {
    const raw = this.el.dataset.payload ?? ""
    this._lastRaw = raw
    const payload = parsePayload(raw)
    const root = this._root
    if (!root) return

    root.innerHTML = ""
    const w = this.el.clientWidth || 320
    const h = this.el.clientHeight || 176
    if (w < 8 || h < 8) return

    if (!payload || !payload.kind) {
      root.innerHTML = "<p class=\"text-xs text-base-content/50 p-2\">Sem dados para o período.</p>"
      return
    }

    const margin = { top: 8, right: 10, bottom: 26, left: 40 }
    const innerW = Math.max(w - margin.left - margin.right, 1)
    const innerH = Math.max(h - margin.top - margin.bottom, 1)

    const svg = d3
      .create("svg")
      .attr("width", w)
      .attr("height", h)
      .attr("role", "img")
      .attr("aria-label", "Gráfico de série temporal")

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

    if (payload.kind === "multi_y") {
      this._drawMultiY(g, payload, innerW, innerH, root)
    } else if (payload.kind === "single_y") {
      this._drawSingleY(g, payload, innerW, innerH, false, root)
    } else if (payload.kind === "cep") {
      this._drawCep(g, payload, innerW, innerH, root)
    } else {
      root.append(svg.node())
      return
    }

    root.append(svg.node())
  },

  _attachLineChartHover(root, g, innerW, innerH, x, y, mode, ctx) {
    const hoverG = g.append("g").attr("class", "d3-bi-hover-layer")
    const focus = hoverG.append("g").attr("class", "d3-bi-focus").style("display", "none")

    focus
      .append("line")
      .attr("class", "d3-bi-crosshair")
      .attr("y1", 0)
      .attr("y2", innerH)
      .attr("stroke", resolveColor("base-content"))
      .attr("stroke-opacity", 0.4)
      .attr("stroke-dasharray", "4 3")
      .attr("pointer-events", "none")

    const dotsG = focus.append("g").attr("class", "d3-bi-dots").attr("pointer-events", "none")

    let tipEl = root.querySelector("[data-d3-bi-tooltip]")
    if (!tipEl) {
      tipEl = document.createElement("div")
      tipEl.setAttribute("data-d3-bi-tooltip", "")
      tipEl.className =
        "pointer-events-none absolute z-30 max-w-[min(18rem,90vw)] rounded-lg border border-base-200 bg-base-100/95 px-2.5 py-2 text-[11px] leading-snug text-base-content shadow-lg backdrop-blur-sm transition-opacity"
      tipEl.style.display = "none"
      tipEl.setAttribute("role", "tooltip")
      root.appendChild(tipEl)
    }

    const hide = () => {
      focus.style("display", "none")
      tipEl.style.display = "none"
    }

    const positionTip = (clientX, clientY) => {
      const r = root.getBoundingClientRect()
      const pad = 10
      let left = clientX - r.left + pad
      let top = clientY - r.top + pad
      const tw = tipEl.offsetWidth || 160
      const th = tipEl.offsetHeight || 48
      if (left + tw > r.width - 4) left = Math.max(4, clientX - r.left - tw - pad)
      if (top + th > r.height - 4) top = Math.max(4, clientY - r.top - th - pad)
      tipEl.style.left = `${left}px`
      tipEl.style.top = `${top}px`
    }

    const onMove = (event) => {
      const [mx] = d3.pointer(event)
      const t0 = x.invert(mx)
      const row = nearestByTime(ctx.rows, t0)
      if (!row) {
        hide()
        return
      }

      const xPos = x(row.t)
      focus.select(".d3-bi-crosshair").attr("x1", xPos).attr("x2", xPos)
      dotsG.selectAll("*").remove()

      let body = ""
      if (mode === "multi") {
        const { series } = ctx
        for (const s of series) {
          const key = s.key
          if (!key) continue
          const v = row.raw[key]
          if (typeof v !== "number" || Number.isNaN(v)) continue
          const label = s.label || key
          const cy = y(v)
          dotsG
            .append("circle")
            .attr("cx", xPos)
            .attr("cy", cy)
            .attr("r", 4)
            .attr("fill", resolveColor(s.color))
            .attr("stroke", resolveColor("base-100"))
            .attr("stroke-width", 1.5)
          body += `<div class="flex justify-between gap-3"><span class="text-base-content/70">${label}</span><span class="font-mono tabular-nums">${fmtHover(v)}</span></div>`
        }
        if (!body) {
          hide()
          return
        }
      } else {
        const vy = row.y
        dotsG
          .append("circle")
          .attr("cx", xPos)
          .attr("cy", y(vy))
          .attr("r", 5)
          .attr("fill", resolveColor(ctx.strokeColor || "secondary"))
          .attr("stroke", resolveColor("base-100"))
          .attr("stroke-width", 1.5)
        body = `<div class="flex justify-between gap-3"><span class="text-base-content/70">Valor</span><span class="font-mono tabular-nums">${fmtHover(vy)}</span></div>`
      }

      tipEl.innerHTML = `<div class="mb-1 font-medium text-base-content/90 border-b border-base-200 pb-1">${tooltipHtmlTimeRow(row.t)}</div>${body}`
      tipEl.style.display = "block"
      positionTip(event.clientX, event.clientY)
      focus.style("display", null)
    }

    hoverG
      .append("rect")
      .attr("width", innerW)
      .attr("height", innerH)
      .attr("fill", "transparent")
      .style("cursor", "crosshair")
      .on("mousemove", onMove)
      .on("mouseleave", hide)
  },

  _drawMultiY(g, payload, innerW, innerH, root) {
    const rows = Array.isArray(payload.rows) ? payload.rows : []
    const series = Array.isArray(payload.series) ? payload.series : []

    const parsed = rows
      .map((r) => ({ t: parseTime(r.t), raw: r }))
      .filter((d) => d.t != null)

    if (parsed.length === 0) {
      g.append("text")
        .attr("x", innerW / 2)
        .attr("y", innerH / 2)
        .attr("text-anchor", "middle")
        .attr("class", "fill-base-content/50")
        .attr("font-size", "11px")
        .text("Sem pontos")
      return
    }

    const x = d3
      .scaleTime()
      .domain(d3.extent(parsed, (d) => d.t))
      .range([0, innerW])

    let yMin = Infinity
    let yMax = -Infinity
    for (const s of series) {
      const key = s.key
      if (!key) continue
      for (const d of parsed) {
        const v = d.raw[key]
        if (typeof v === "number" && !Number.isNaN(v)) {
          yMin = Math.min(yMin, v)
          yMax = Math.max(yMax, v)
        }
      }
    }
    if (!Number.isFinite(yMin) || !Number.isFinite(yMax)) {
      yMin = 0
      yMax = 1
    }
    if (yMin === yMax) {
      yMin -= 1
      yMax += 1
    }
    const pad = (yMax - yMin) * 0.06 || 0.01
    const y = d3
      .scaleLinear()
      .domain([yMin - pad, yMax + pad])
      .nice()
      .range([innerH, 0])

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(Math.min(6, Math.floor(innerW / 72)))
          .tickFormat(d3.timeFormat("%d/%m %H:%M"))
      )
      .call((ga) => ga.selectAll("text").attr("font-size", "9px").attr("transform", "rotate(-25)").style("text-anchor", "end"))
      .call((ga) => ga.select(".domain").attr("stroke", "currentColor").attr("class", "text-base-content/30"))
      .call((ga) => ga.selectAll(".tick line").attr("stroke", "currentColor").attr("class", "text-base-content/20"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(4).tickFormat(d3.format(".3~s")))
      .call((ga) => ga.select(".domain").attr("stroke", "currentColor").attr("class", "text-base-content/30"))
      .call((ga) => ga.selectAll(".tick line").attr("stroke", "currentColor").attr("class", "text-base-content/20"))
      .call((ga) => ga.selectAll("text").attr("font-size", "9px"))

    for (const s of series) {
      const key = s.key
      if (!key) continue
      const color = resolveColor(s.color)
      const seriesData = parsed.filter(
        (d) => typeof d.raw[key] === "number" && !Number.isNaN(d.raw[key])
      )
      const ln = d3
        .line()
        .x((d) => x(d.t))
        .y((d) => y(d.raw[key]))
        .curve(d3.curveMonotoneX)
      g.append("path")
        .datum(seriesData)
        .attr("fill", "none")
        .attr("stroke", color)
        .attr("stroke-width", key === "oee" ? 2 : 1.4)
        .attr("d", ln)
    }

    this._attachLineChartHover(root, g, innerW, innerH, x, y, "multi", { rows: parsed, series })
  },

  _drawSingleY(g, payload, innerW, innerH, withRefs, root) {
    const rows = Array.isArray(payload.rows) ? payload.rows : []
    const color = resolveColor(payload.color || "secondary")

    const parsed = rows
      .map((r) => ({ t: parseTime(r.t), y: r.y }))
      .filter((d) => d.t != null && typeof d.y === "number" && !Number.isNaN(d.y))

    if (parsed.length === 0) {
      g.append("text")
        .attr("x", innerW / 2)
        .attr("y", innerH / 2)
        .attr("text-anchor", "middle")
        .attr("font-size", "11px")
        .attr("class", "fill-base-content/50")
        .text("Sem pontos")
      return
    }

    const x = d3
      .scaleTime()
      .domain(d3.extent(parsed, (d) => d.t))
      .range([0, innerW])

    let yMin = d3.min(parsed, (d) => d.y)
    let yMax = d3.max(parsed, (d) => d.y)
    if (withRefs && Array.isArray(payload.ref_lines)) {
      for (const rl of payload.ref_lines) {
        const v = rl.value
        if (typeof v === "number" && !Number.isNaN(v)) {
          yMin = Math.min(yMin, v)
          yMax = Math.max(yMax, v)
        }
      }
    }
    if (yMin === yMax) {
      yMin -= 1
      yMax += 1
    }
    const pad = (yMax - yMin) * 0.06 || 0.01
    const y = d3
      .scaleLinear()
      .domain([yMin - pad, yMax + pad])
      .nice()
      .range([innerH, 0])

    if (withRefs && Array.isArray(payload.ref_lines)) {
      for (const rl of payload.ref_lines) {
        const v = rl.value
        if (typeof v !== "number" || Number.isNaN(v)) continue
        const cy = y(v)
        if (!Number.isFinite(cy)) continue
        const stroke = resolveColor(rl.color || "warning")
        const dash = rl.dash ? "4,3" : null
        g.append("line")
          .attr("x1", 0)
          .attr("x2", innerW)
          .attr("y1", cy)
          .attr("y2", cy)
          .attr("stroke", stroke)
          .attr("stroke-width", 1)
          .attr("stroke-dasharray", dash || null)
          .attr("opacity", 0.85)
      }
    }

    const line = d3
      .line()
      .x((d) => x(d.t))
      .y((d) => y(d.y))
      .curve(d3.curveMonotoneX)

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(Math.min(6, Math.floor(innerW / 72)))
          .tickFormat(d3.timeFormat("%d/%m %H:%M"))
      )
      .call((ga) => ga.selectAll("text").attr("font-size", "9px").attr("transform", "rotate(-25)").style("text-anchor", "end"))
      .call((ga) => ga.select(".domain").attr("stroke", "currentColor").attr("class", "text-base-content/30"))
      .call((ga) => ga.selectAll(".tick line").attr("stroke", "currentColor").attr("class", "text-base-content/20"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(4).tickFormat(d3.format(".3~s")))
      .call((ga) => ga.select(".domain").attr("stroke", "currentColor").attr("class", "text-base-content/30"))
      .call((ga) => ga.selectAll(".tick line").attr("stroke", "currentColor").attr("class", "text-base-content/20"))
      .call((ga) => ga.selectAll("text").attr("font-size", "9px"))

    g.append("path")
      .datum(parsed)
      .attr("fill", "none")
      .attr("stroke", color)
      .attr("stroke-width", 2)
      .attr("d", line)

    this._attachLineChartHover(root, g, innerW, innerH, x, y, "single", {
      rows: parsed,
      strokeColor: payload.color || "secondary"
    })
  },

  _drawCep(g, payload, innerW, innerH, root) {
    const refLines = []
    if (Array.isArray(payload.ref_lines)) {
      for (const rl of payload.ref_lines) {
        if (rl && typeof rl.value === "number" && !Number.isNaN(rl.value)) refLines.push(rl)
      }
    }
    this._drawSingleY(g, { ...payload, ref_lines: refLines }, innerW, innerH, true, root)
  }
}

export default D3BiChartHook
