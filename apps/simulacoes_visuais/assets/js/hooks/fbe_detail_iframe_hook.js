/**
 * LiveView hook: sends FBE facts (real-time telemetry) to the iframe "Modelo 3D detalhado"
 * via postMessage so the static 3D page can update its HUD and detail panel.
 */
function sendFactsToIframe(hookEl) {
  const fbeId = hookEl.dataset.fbeId
  const factsJson = hookEl.dataset.fbeFacts
  if (!fbeId || !factsJson) return

  const iframe = hookEl.querySelector("iframe")
  if (!iframe || !iframe.contentWindow) return

  let facts
  try {
    facts = JSON.parse(factsJson)
  } catch (_) {
    return
  }

  iframe.contentWindow.postMessage(
    { type: "fbe_facts", fbeId: parseInt(fbeId, 10), facts },
    window.location.origin
  )
}

const FbeDetailIframeHook = {
  mounted() {
    const iframe = this.el.querySelector("iframe")
    if (iframe) {
      iframe.addEventListener("load", () => {
        setTimeout(() => sendFactsToIframe(this.el), 0)
      })
    }
    sendFactsToIframe(this.el)
  },

  updated() {
    sendFactsToIframe(this.el)
  }
}

export default FbeDetailIframeHook
