/**
 * LiveView hook: render Mermaid diagrams from data-mermaid-source.
 * Isolated in its own file to avoid agent/merge conflicts.
 */
const MermaidHook = {
  mounted() {
    this.renderMermaid()
  },
  updated() {
    const source = this.el.dataset.mermaidSource ?? ""
    if (source && source !== (this._lastSource ?? "")) {
      this._lastSource = source
      this.renderMermaid()
    }
  },
  renderMermaid() {
    if (typeof window.mermaid === "undefined") return
    if (!window.mermaid.run) {
      window.mermaid.initialize({ startOnLoad: false, theme: "base" })
    }
    const source = this.el.dataset.mermaidSource ?? ""
    const container = this.el.querySelector("[data-mermaid-container]")
    if (!container || !source.trim()) return
    this._lastSource = source
    container.innerHTML = ""
    const pre = document.createElement("pre")
    pre.className = "mermaid"
    pre.textContent = source
    container.appendChild(pre)
    window.mermaid.run({ nodes: [pre], suppressErrors: true }).catch(() => {
      container.innerHTML = "<p class=\"text-sm text-base-content/60 p-4\">Diagrama temporariamente indisponível.</p>"
    })
  }
}

export default MermaidHook
