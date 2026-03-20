// Phoenix LiveView app entry point.
// Hooks are in separate files to avoid merge conflicts: mermaid_hook.js, scene_3d_hook.js, d3_bi_chart_hook.js

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/simulacoes_visuais"
import topbar from "../vendor/topbar"

import MermaidHook from "./hooks/mermaid_hook.js"
import Scene3DHook from "./hooks/scene_3d_hook.js"
import FbeDetailIframeHook from "./hooks/fbe_detail_iframe_hook.js"
import D3BiChartHook from "./hooks/d3_bi_chart_hook.js"

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: {
    Mermaid: MermaidHook,
    Scene3D: Scene3DHook,
    FbeDetailIframe: FbeDetailIframeHook,
    D3BiChart: D3BiChartHook,
    ...colocatedHooks
  }
})

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", () => topbar.show(300))
window.addEventListener("phx:page-loading-stop", () => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    reloader.enableServerLogs()
    let keyDown
    window.addEventListener("keydown", (e) => (keyDown = e.key))
    window.addEventListener("keyup", () => (keyDown = null))
    window.addEventListener(
      "click",
      (e) => {
        if (keyDown === "c") {
          e.preventDefault()
          e.stopImmediatePropagation()
          reloader.openEditorAtCaller(e.target)
        } else if (keyDown === "d") {
          e.preventDefault()
          e.stopImmediatePropagation()
          reloader.openEditorAtDef(e.target)
        }
      },
      true
    )
    window.liveReloader = reloader
  })
}
