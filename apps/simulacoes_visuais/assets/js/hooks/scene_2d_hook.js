/**
 * LiveView hook: 2D canvas scene (pipeline, FBE icons, rules, pan/zoom, select_fbe_2d).
 * Isolated in its own file to avoid agent/merge conflicts.
 * Used when the 2D view is in "canvas" mode; the main 2D view can use the SVG component instead.
 */
const STATUS_COLORS_2D = { normal: "#22c55e", warning: "#eab308", active: "#3b82f6" }

function drawFbeCircle(ctx, x, y, size, color) {
  ctx.fillStyle = color
  ctx.beginPath()
  ctx.arc(x, y, size, 0, Math.PI * 2)
  ctx.fill()
  ctx.strokeStyle = "rgba(0,0,0,0.2)"
  ctx.lineWidth = 1
  ctx.stroke()
}

const FBE_DRAWERS = {
  1(ctx, x, y, size, color) {
    const n = 10
    const r0 = size * 0.5
    const r1 = size * 0.85
    ctx.fillStyle = color
    ctx.beginPath()
    for (let i = 0; i < n * 2; i++) {
      const r = i % 2 === 0 ? r1 : r0
      const a = (Math.PI * 2 * i) / (n * 2)
      const px = x + r * Math.cos(a)
      const py = y + r * Math.sin(a)
      if (i === 0) ctx.moveTo(px, py)
      else ctx.lineTo(px, py)
    }
    ctx.closePath()
    ctx.fill()
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.stroke()
  },
  2(ctx, x, y, size, color) {
    const w = size * 0.9
    const h = size * 1.6
    const r = size * 0.2
    const left = x - w / 2
    const top = y - h / 2
    ctx.fillStyle = color
    if (ctx.roundRect) {
      ctx.beginPath()
      ctx.roundRect(left, top, w, h, r)
      ctx.fill()
    } else {
      ctx.fillRect(left, top, w, h)
    }
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.strokeRect(left, top, w, h)
  },
  3(ctx, x, y, size, color) {
    const w = size * 1.5
    const h = size * 0.7
    const r = size * 0.25
    const left = x - w / 2
    const top = y - h / 2
    ctx.fillStyle = color
    if (ctx.roundRect) {
      ctx.beginPath()
      ctx.roundRect(left, top, w, h, r)
      ctx.fill()
    } else {
      ctx.fillRect(left, top, w, h)
    }
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.strokeRect(left, top, w, h)
  },
  4(ctx, x, y, size, color) {
    const r = size * 0.85
    ctx.fillStyle = color
    ctx.beginPath()
    ctx.arc(x, y, r, 0, Math.PI * 2)
    ctx.fill()
    ctx.beginPath()
    ctx.arc(x, y - r * 0.3, r * 0.4, Math.PI * 0.7, Math.PI * 1.3)
    ctx.strokeStyle = "rgba(0,0,0,0.3)"
    ctx.lineWidth = 2
    ctx.stroke()
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.arc(x, y, r, 0, Math.PI * 2)
    ctx.stroke()
  },
  5(ctx, x, y, size, color) {
    const r = size * 0.55
    ctx.fillStyle = color
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.arc(x - r * 0.4, y, r, 0, Math.PI * 2)
    ctx.fill()
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(x + r * 0.4, y, r, 0, Math.PI * 2)
    ctx.fill()
    ctx.stroke()
  },
  6(ctx, x, y, size, color) {
    const w = size * 0.75
    const h = size * 1.4
    const r = size * 0.2
    const left = x - w / 2
    const top = y - h / 2
    ctx.fillStyle = color
    if (ctx.roundRect) {
      ctx.beginPath()
      ctx.roundRect(left, top, w, h, r)
      ctx.fill()
    } else {
      ctx.fillRect(left, top, w, h)
    }
    ctx.beginPath()
    ctx.ellipse(x, top, w / 2, r, 0, 0, Math.PI * 2)
    ctx.fill()
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.strokeRect(left, top, w, h)
    ctx.stroke()
  },
  7(ctx, x, y, size, color) {
    const w = size * 0.75
    const h = size * 1.4
    const r = size * 0.2
    const left = x - w / 2
    const top = y - h / 2
    ctx.fillStyle = color
    if (ctx.roundRect) {
      ctx.beginPath()
      ctx.roundRect(left, top, w, h, r)
      ctx.fill()
    } else {
      ctx.fillRect(left, top, w, h)
    }
    ctx.beginPath()
    ctx.ellipse(x, top, w / 2, r, 0, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = "rgba(255,255,255,0.2)"
    ctx.fillRect(x - size * 0.15, y - size * 0.3, size * 0.3, size * 0.25)
    ctx.fillStyle = color
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.strokeRect(left, top, w, h)
    ctx.stroke()
  },
  8(ctx, x, y, size, color) {
    const barW = size * 1.6
    const barH = size * 0.25
    ctx.fillStyle = color
    ctx.fillRect(x - barW / 2, y - barH / 2, barW, barH)
    const bw = size * 0.2
    const bh = size * 0.5
    for (let i = -1; i <= 1; i++) {
      ctx.fillRect(x + i * size * 0.5 - bw / 2, y - bh / 2 - size * 0.1, bw, bh)
    }
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.strokeRect(x - barW / 2, y - barH / 2, barW, barH)
  },
  9(ctx, x, y, size, color) {
    const r = size * 0.8
    ctx.fillStyle = color
    ctx.beginPath()
    ctx.arc(x, y, r, 0, Math.PI * 2)
    ctx.fill()
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.stroke()
    const dropR = size * 0.2
    for (const [dx, dy] of [[-0.3, -0.2], [0.25, 0.1], [0, 0.35], [-0.2, 0.15]]) {
      ctx.beginPath()
      ctx.arc(x + size * dx, y + size * dy, dropR, 0, Math.PI * 2)
      ctx.fillStyle = "rgba(255,255,255,0.5)"
      ctx.fill()
      ctx.fillStyle = color
    }
  },
  10(ctx, x, y, size, color) {
    const w = size * 1.2
    const h = size * 0.6
    const left = x - w / 2
    const top = y - h / 2
    ctx.fillStyle = color
    if (ctx.roundRect) {
      ctx.beginPath()
      ctx.roundRect(left, top, w, h, size * 0.15)
      ctx.fill()
    } else {
      ctx.fillRect(left, top, w, h)
    }
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.strokeRect(left, top, w, h)
    const wheelR = size * 0.22
    ctx.fillStyle = "rgba(0,0,0,0.4)"
    ctx.beginPath()
    ctx.arc(x - w / 4, y + h / 2, wheelR, 0, Math.PI * 2)
    ctx.fill()
    ctx.beginPath()
    ctx.arc(x + w / 4, y + h / 2, wheelR, 0, Math.PI * 2)
    ctx.fill()
  },
  11(ctx, x, y, size, color) {
    const s = size * 0.35
    const pts = [
      [x + s, y - size * 0.9],
      [x - s * 0.5, y],
      [x + s * 0.5, y],
      [x - s, y + size * 0.9],
      [x, y + size * 0.3],
      [x + s, y - size * 0.3]
    ]
    ctx.fillStyle = color
    ctx.beginPath()
    ctx.moveTo(pts[0][0], pts[0][1])
    ctx.lineTo(pts[1][0], pts[1][1])
    ctx.lineTo(pts[2][0], pts[2][1])
    ctx.lineTo(pts[3][0], pts[3][1])
    ctx.lineTo(pts[4][0], pts[4][1])
    ctx.lineTo(pts[5][0], pts[5][1])
    ctx.closePath()
    ctx.fill()
    ctx.strokeStyle = "rgba(0,0,0,0.2)"
    ctx.lineWidth = 1
    ctx.stroke()
  }
}

const SCENE_2D_W = 1200
const SCENE_2D_H = 520
const SCENE_2D_PADDING = 90
const SCENE_2D_BASE_RADIUS = 24

function formatSceneValue(v) {
  if (v == null) return "—"
  if (typeof v === "number") return Number.isInteger(v) ? String(v) : v.toFixed(1)
  if (typeof v === "boolean") return v ? "ON" : "OFF"
  return String(v)
}

function scene2dNodeXs() {
  const step = (SCENE_2D_W - 2 * SCENE_2D_PADDING) / 10
  const out = []
  for (let i = 0; i < 11; i++) out.push(SCENE_2D_PADDING + i * step)
  return out
}

const Scene2DHook = {
  mounted() {
    const container = this.el.querySelector("[data-scene-container]")
    if (!container) return
    const width = Math.max(300, container.clientWidth || 600)
    const height = Math.max(400, container.clientHeight || 400)
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    const canvas = document.createElement("canvas")
    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.width = width + "px"
    canvas.style.height = height + "px"
    canvas.style.cursor = "grab"
    container.appendChild(canvas)
    const ctx = canvas.getContext("2d")
    if (!ctx) return
    ctx.scale(dpr, dpr)
    this._canvas = canvas
    this._ctx = ctx
    this._width = width
    this._height = height
    this._scale = 1
    this._panX = SCENE_2D_W / 2
    this._panY = SCENE_2D_H / 2
    this._lastState = null
    this._updatedAt = {}
    this._particles = Array.from({ length: 8 }, (_, i) => ({ t: i * 1.2, speed: 0.015 }))
    this._lastTime = 0
    this._hoveredNode = null
    this._pointerDownNode = null
    this._pointerDownXY = null
    const baseScale = () => Math.min(this._width / SCENE_2D_W, this._height / SCENE_2D_H)
    const sceneFromClient = (clientX, clientY) => {
      const rect = canvas.getBoundingClientRect()
      const mx = clientX - rect.left
      const my = clientY - rect.top
      const scale = baseScale() * this._scale
      const offsetX = width / 2 - this._panX * scale
      const offsetY = height / 2 - this._panY * scale
      return { x: (mx - offsetX) / scale, y: (my - offsetY) / scale }
    }
    const hitTest = (sceneX, sceneY) => {
      const nodeXs = scene2dNodeXs()
      const y = SCENE_2D_H / 2
      const r = SCENE_2D_BASE_RADIUS + 4
      for (let i = 0; i < 11; i++) {
        const dx = sceneX - nodeXs[i]
        const dy = sceneY - y
        if (dx * dx + dy * dy <= r * r) return i + 1
      }
      return null
    }
    const onWheel = (e) => {
      e.preventDefault()
      const rect = canvas.getBoundingClientRect()
      const mx = e.clientX - rect.left
      const my = e.clientY - rect.top
      const base = baseScale()
      const scale = base * this._scale
      const factor = e.deltaY > 0 ? 0.9 : 1.1
      this._scale = Math.max(0.2, Math.min(4, this._scale * factor))
      const newScale = base * this._scale
      const sx = this._panX + (mx - width / 2) / scale
      const sy = this._panY + (my - height / 2) / scale
      this._panX = sx - (mx - width / 2) / newScale
      this._panY = sy - (my - height / 2) / newScale
    }
    let dragging = false
    let startX = 0, startY = 0, startPanX = 0, startPanY = 0
    const DRAG_THRESHOLD = 5
    const onPointerDown = (e) => {
      if (e.button !== 0) return
      const pt = sceneFromClient(e.clientX, e.clientY)
      this._pointerDownNode = hitTest(pt.x, pt.y)
      this._pointerDownXY = [e.clientX, e.clientY]
      startX = e.clientX
      startY = e.clientY
      startPanX = this._panX
      startPanY = this._panY
      dragging = false
      canvas.style.cursor = this._pointerDownNode ? "pointer" : "grabbing"
    }
    const onPointerMove = (e) => {
      if (this._pointerDownXY === null) {
        const rect = canvas.getBoundingClientRect()
        if (e.clientX < rect.left || e.clientX > rect.right || e.clientY < rect.top || e.clientY > rect.bottom) {
          this._hoveredNode = null
          return
        }
        const pt = sceneFromClient(e.clientX, e.clientY)
        this._hoveredNode = hitTest(pt.x, pt.y)
        return
      }
      const dx = e.clientX - startX
      const dy = e.clientY - startY
      if (!dragging && (dx * dx + dy * dy > DRAG_THRESHOLD * DRAG_THRESHOLD)) dragging = true
      if (dragging) {
        const scale = baseScale() * this._scale
        this._panX = startPanX + (startX - e.clientX) / scale
        this._panY = startPanY + (startY - e.clientY) / scale
        canvas.style.cursor = "grabbing"
      }
    }
    const onPointerUp = () => {
      if (this._pointerDownXY !== null && !dragging && this.pushEvent) {
        this.pushEvent("select_fbe_2d", { id: this._pointerDownNode })
      }
      this._pointerDownXY = null
      this._pointerDownNode = null
      dragging = false
      canvas.style.cursor = "grab"
    }
    const onPointerLeave = () => {
      this._hoveredNode = null
      this._pointerDownXY = null
      dragging = false
      canvas.style.cursor = "grab"
    }
    canvas.addEventListener("wheel", onWheel, { passive: false })
    canvas.addEventListener("pointerdown", onPointerDown)
    window.addEventListener("pointermove", onPointerMove)
    window.addEventListener("pointerup", onPointerUp)
    canvas.addEventListener("pointerleave", onPointerLeave)
    this._cleanup = () => {
      canvas.removeEventListener("wheel", onWheel)
      canvas.removeEventListener("pointerdown", onPointerDown)
      window.removeEventListener("pointermove", onPointerMove)
      window.removeEventListener("pointerup", onPointerUp)
      canvas.removeEventListener("pointerleave", onPointerLeave)
    }
    const animate = (time) => {
      this._rafId = requestAnimationFrame(animate)
      this._draw(time)
    }
    this._rafId = requestAnimationFrame(animate)
  },
  updated() {
    if (this._canvas && this._hoveredNode !== null && this._pointerDownXY === null)
      this._canvas.style.cursor = "pointer"
    else if (this._canvas && this._pointerDownXY === null)
      this._canvas.style.cursor = "grab"
  },
  destroyed() {
    if (this._rafId) cancelAnimationFrame(this._rafId)
    if (this._cleanup) this._cleanup()
    if (this._canvas && this._canvas.parentNode) this._canvas.parentNode.removeChild(this._canvas)
  },
  _draw(time) {
    const ctx = this._ctx
    const width = this._width
    const height = this._height
    if (!ctx) return
    const delta = time - this._lastTime
    this._lastTime = time
    let selectedId = null
    const rawSelected = this.el.dataset.sceneSelected
    if (rawSelected !== undefined && rawSelected !== "") {
      const n = parseInt(rawSelected, 10)
      if (!isNaN(n) && n >= 1 && n <= 11) selectedId = n
    }
    if (this._canvas) {
      if (this._pointerDownXY !== null) this._canvas.style.cursor = this._pointerDownNode ? "pointer" : "grabbing"
      else if (this._hoveredNode !== null) this._canvas.style.cursor = "pointer"
      else this._canvas.style.cursor = "grab"
    }
    let state = []
    try {
      const raw = this.el.dataset.sceneState
      if (raw) state = JSON.parse(raw)
      if (!Array.isArray(state)) state = Object.values(state || {})
    } catch (_) {}
    if (this._lastState && state.length) {
      state.forEach((item) => {
        const prev = this._lastState.find((s) => s.id === item.id)
        if (!prev || prev.status !== item.status || prev.value !== item.value)
          this._updatedAt[item.id] = time
      })
    }
    this._lastState = state.map((s) => ({ id: s.id, status: s.status, value: s.value }))
    const scale0 = Math.min(width / SCENE_2D_W, height / SCENE_2D_H)
    const scale = scale0 * this._scale
    const offsetX = width / 2 - this._panX * scale
    const offsetY = height / 2 - this._panY * scale
    ctx.clearRect(0, 0, width, height)
    ctx.save()
    ctx.translate(offsetX, offsetY)
    ctx.scale(scale, scale)
    const padding = SCENE_2D_PADDING
    const step = (SCENE_2D_W - 2 * padding) / 10
    const y = SCENE_2D_H / 2
    const baseRadius = SCENE_2D_BASE_RADIUS
    const nodeXs = scene2dNodeXs()
    const grad = ctx.createLinearGradient(0, 0, SCENE_2D_W, SCENE_2D_H)
    grad.addColorStop(0, "#0f172a")
    grad.addColorStop(0.5, "#1e293b")
    grad.addColorStop(1, "#0f172a")
    ctx.fillStyle = grad
    ctx.fillRect(-50, -50, SCENE_2D_W + 100, SCENE_2D_H + 100)
    ctx.strokeStyle = "rgba(30, 41, 59, 0.8)"
    ctx.lineWidth = 1
    for (let gx = 0; gx <= SCENE_2D_W; gx += 60) {
      ctx.beginPath()
      ctx.moveTo(gx, 0)
      ctx.lineTo(gx, SCENE_2D_H)
      ctx.stroke()
    }
    for (let gy = 0; gy <= SCENE_2D_H; gy += 52) {
      ctx.beginPath()
      ctx.moveTo(0, gy)
      ctx.lineTo(SCENE_2D_W, gy)
      ctx.stroke()
    }
    ctx.font = "bold 14px system-ui, sans-serif"
    ctx.fillStyle = "rgba(226, 232, 240, 0.9)"
    ctx.textAlign = "center"
    ctx.fillText("Smart Brewery · Vista 2D", SCENE_2D_W / 2, 28)
    let rules = []
    try {
      const rawRules = this.el.dataset.sceneRules
      if (rawRules) rules = JSON.parse(rawRules)
      if (!Array.isArray(rules)) rules = []
    } catch (_) {}
    const ruleY = 72
    const ruleXs = [padding + 2 * step, padding + 5 * step, padding + 8 * step]
    rules.forEach((rule, idx) => {
      const rx = ruleXs[idx] != null ? ruleXs[idx] : padding + (idx + 1) * step
      const watch = rule.watch || []
      const action = rule.action || []
      ctx.setLineDash([4, 4])
      ctx.strokeStyle = "rgba(148, 163, 184, 0.5)"
      ctx.lineWidth = 1.5
      watch.forEach((fbeId) => {
        const fx = nodeXs[Number(fbeId) - 1]
        if (fx == null) return
        ctx.beginPath()
        ctx.moveTo(rx, ruleY)
        ctx.lineTo(fx, y - baseRadius)
        ctx.stroke()
      })
      ctx.setLineDash([])
      ctx.strokeStyle = "rgba(59, 130, 246, 0.6)"
      ctx.lineWidth = 2
      action.forEach((fbeId) => {
        const fx = nodeXs[Number(fbeId) - 1]
        if (fx == null) return
        ctx.beginPath()
        ctx.moveTo(rx, ruleY)
        ctx.lineTo(fx, y - baseRadius)
        ctx.stroke()
      })
      ctx.fillStyle = "rgba(30, 58, 138, 0.9)"
      ctx.strokeStyle = "rgba(59, 130, 246, 0.8)"
      ctx.lineWidth = 1.5
      const rh = 14
      const rw = 22
      const rleft = rx - rw / 2
      const rtop = ruleY - rh / 2
      ctx.fillRect(rleft, rtop, rw, rh)
      ctx.strokeRect(rleft, rtop, rw, rh)
      ctx.fillStyle = "rgba(226, 232, 240, 0.95)"
      ctx.font = "10px system-ui, sans-serif"
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillText("R_0" + (rule.id || idx + 1), rx, ruleY)
      ctx.textBaseline = "alphabetic"
    })
    ctx.strokeStyle = "rgba(94, 234, 212, 0.25)"
    ctx.lineWidth = 4
    for (let i = 0; i < 10; i++) {
      const x0 = nodeXs[i] + baseRadius
      const x1 = nodeXs[i + 1] - baseRadius
      const gr = ctx.createLinearGradient(x0, y, x1, y)
      gr.addColorStop(0, "rgba(34, 197, 94, 0.4)")
      gr.addColorStop(1, "rgba(59, 130, 246, 0.4)")
      ctx.strokeStyle = gr
      ctx.beginPath()
      ctx.moveTo(x0, y)
      ctx.lineTo(x1, y)
      ctx.stroke()
    }
    this._particles.forEach((p) => {
      p.t += p.speed * (delta || 16)
      if (p.t > 11) p.t -= 11
      if (p.t < 0) p.t += 11
      const idx = Math.floor(p.t)
      const frac = p.t - idx
      const i0 = Math.max(0, Math.min(idx, 9))
      const i1 = Math.min(10, i0 + 1)
      const x = nodeXs[i0] + (nodeXs[i1] - nodeXs[i0]) * (idx < 10 ? frac : 1)
      const px = idx < 10 ? x : nodeXs[10]
      const py = y
      ctx.fillStyle = "rgba(94, 234, 212, 0.9)"
      ctx.beginPath()
      ctx.arc(px, py, 4, 0, Math.PI * 2)
      ctx.fill()
      ctx.strokeStyle = "rgba(255,255,255,0.6)"
      ctx.lineWidth = 1
      ctx.stroke()
    })
    ctx.strokeStyle = "rgba(255,255,255,0.15)"
    ctx.lineWidth = 2
    for (let i = 0; i < 11; i++) {
      const x = nodeXs[i]
      const item = state.find((s) => s.id === i + 1) || {}
      const status = item.status || "normal"
      const color = STATUS_COLORS_2D[status] || STATUS_COLORS_2D.normal
      const pulse = status === "active" ? 1 + 0.12 * Math.sin(time * 0.003) : 1
      const r = baseRadius * pulse
      const flash = this._updatedAt[i + 1] != null && (time - this._updatedAt[i + 1]) < 700
      if (flash) {
        const alpha = 1 - (time - this._updatedAt[i + 1]) / 700
        ctx.strokeStyle = `rgba(255, 255, 100, ${alpha * 0.9})`
        ctx.lineWidth = 4
        ctx.beginPath()
        ctx.arc(x, y, r + 8, 0, Math.PI * 2)
        ctx.stroke()
      }
      if (i < 10) {
        ctx.strokeStyle = "rgba(255,255,255,0.15)"
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(nodeXs[i + 1] - baseRadius, y)
        ctx.stroke()
      }
      const drawer = FBE_DRAWERS[i + 1]
      if (drawer) drawer(ctx, x, y, r, color)
      else drawFbeCircle(ctx, x, y, r, color)
      if (selectedId === i + 1) {
        ctx.strokeStyle = "rgba(59, 130, 246, 0.9)"
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.arc(x, y, r + 6, 0, Math.PI * 2)
        ctx.stroke()
      }
      ctx.strokeStyle = "rgba(255,255,255,0.15)"
      ctx.lineWidth = 2
      ctx.fillStyle = "#e2e8f0"
      ctx.font = "11px system-ui, sans-serif"
      ctx.textAlign = "center"
      ctx.fillText("FBE_" + String(i + 1).padStart(2, "0"), x, y + r + 12)
      const valStr = formatSceneValue(item.value)
      ctx.font = "10px system-ui, sans-serif"
      ctx.fillStyle = status === "warning" ? "#fef08a" : status === "active" ? "#93c5fd" : "rgba(226, 232, 240, 0.85)"
      ctx.fillText(valStr, x, y + r + 26)
      ctx.fillStyle = "rgba(148, 163, 184, 0.8)"
      ctx.font = "9px system-ui, sans-serif"
      const label = (item.label || "").replace(/_/g, " ")
      if (label) ctx.fillText(label.length > 12 ? label.slice(0, 11) + "…" : label, x, y - r - 6)
    }
    if (this._hoveredNode !== null && this._pointerDownXY === null) {
      const item = state.find((s) => s.id === this._hoveredNode) || {}
      const tx = nodeXs[this._hoveredNode - 1]
      const ty = y - baseRadius - 28
      const label = (item.label || "FBE_" + String(this._hoveredNode).padStart(2, "0")).replace(/_/g, " ")
      const valStr = formatSceneValue(item.value)
      ctx.font = "11px system-ui, sans-serif"
      ctx.textAlign = "center"
      const w = Math.max(ctx.measureText(label).width, ctx.measureText(valStr).width) + 16
      const h = 32
      ctx.fillStyle = "rgba(15, 23, 42, 0.92)"
      ctx.strokeStyle = "rgba(59, 130, 246, 0.7)"
      ctx.lineWidth = 1.5
      ctx.fillRect(tx - w / 2, ty - h, w, h)
      ctx.strokeRect(tx - w / 2, ty - h, w, h)
      ctx.fillStyle = "#e2e8f0"
      ctx.fillText(label, tx, ty - h + 12)
      ctx.fillStyle = "rgba(148, 163, 184, 0.95)"
      ctx.font = "10px system-ui, sans-serif"
      ctx.fillText(valStr, tx, ty - h + 24)
    }
    ctx.restore()
  }
}

export default Scene2DHook
