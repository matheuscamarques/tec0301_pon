/**
 * LiveView hook: wrapper for iframe that loads the Digital Twin 3D model (digital_twin_3d.html).
 * Listens for postMessage({ type: "select_fbe_3d", id: 1..11 }) from the iframe and pushes to LiveView.
 * Isolated in its own file to avoid agent/merge conflicts.
 */
const Scene3DIframeHook = {
  mounted() {
    this._iframe = this.el.querySelector("iframe")
    this._onMessage = (e) => {
      if (!e.data || e.data.type !== "select_fbe_3d") return
      const iframe = this.el.querySelector("iframe")
      if (iframe && e.source !== iframe.contentWindow) return
      const id = e.data.id
      if (id != null && Number(id) >= 1 && Number(id) <= 11) {
        this.pushEvent("select_fbe_3d", { id: String(id) })
      }
    }
    window.addEventListener("message", this._onMessage)
  },
  destroyed() {
    window.removeEventListener("message", this._onMessage)
  }
}

export default Scene3DIframeHook
