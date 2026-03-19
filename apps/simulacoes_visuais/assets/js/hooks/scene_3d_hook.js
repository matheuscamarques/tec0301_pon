/**
 * LiveView hook: 3D Digital Twin scene (factory model). Uses buildDigitalTwinScene and OrbitControls.
 * Applies data-scene-state (status colors) and data-scene-selected (emissive); click pushes select_fbe_3d.
 */
import { buildDigitalTwinScene } from "../scenes/digital_twin_3d/index.js"

const STATUS_COLORS = { normal: 0x22c55e, warning: 0xeab308, active: 0x3b82f6 }

const Scene3DHook = {
  mounted() {
    if (typeof window.THREE === "undefined") {
      const container = this.el.querySelector("[data-scene-container]")
      if (container) container.innerHTML = "<p class=\"p-4 text-base-content/70\">Vista 3D indisponível (Three.js não carregado).</p>"
      return
    }
    if (typeof window.THREE.OrbitControls === "undefined") {
      const container = this.el.querySelector("[data-scene-container]")
      if (container) container.innerHTML = "<p class=\"p-4 text-base-content/70\">Vista 3D indisponível (OrbitControls não carregado).</p>"
      return
    }
    const THREE = window.THREE
    const container = this.el.querySelector("[data-scene-container]")
    if (!container) return
    const width = container.clientWidth || 800
    const height = Math.max(480, container.clientHeight || 480)

    const built = buildDigitalTwinScene(THREE, container, { width, height })
    if (!built) {
      container.innerHTML = "<p class=\"p-4 text-base-content/70\">Vista 3D: falha ao construir cena.</p>"
      return
    }
    const { scene, camera, renderer, controls, interactables, steamParticles, bottles, rotorGroup, amr, stateHandles } = built
    const safeInteractables = Array.isArray(interactables) ? interactables : []
    this._stateHandles = stateHandles || {}

    const canvas = renderer.domElement
    canvas.style.display = "block"
    canvas.style.width = "100%"
    canvas.style.height = "100%"
    canvas.style.touchAction = "none"

    this._scene = scene
    this._camera = camera
    this._renderer = renderer
    this._controls = controls
    this._interactables = safeInteractables
    this._steamParticles = steamParticles
    this._bottles = bottles
    this._rotorGroup = rotorGroup
    this._amr = amr
    this._container = container

    const mouse = new THREE.Vector2()
    const raycaster = new THREE.Raycaster()
    let pointerDownTarget = null
    let pointerDownX = 0
    let pointerDownY = 0
    const DRAG_THRESHOLD = 5
    this._hoveredObject = null

    const onPointerDown = (e) => {
      pointerDownTarget = e.target
      pointerDownX = e.clientX
      pointerDownY = e.clientY
    }
    const onPointerClick = (e) => {
      if (e.target !== pointerDownTarget) return
      const dx = e.clientX - pointerDownX
      const dy = e.clientY - pointerDownY
      if (dx * dx + dy * dy > DRAG_THRESHOLD * DRAG_THRESHOLD) return
      const rect = canvas.getBoundingClientRect()
      if (rect.width <= 0 || rect.height <= 0) return
      mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1
      mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1
      scene.updateMatrixWorld(true)
      raycaster.setFromCamera(mouse, camera)
      const hits = raycaster.intersectObjects(safeInteractables, false)
      if (hits.length > 0 && hits[0].object.userData && hits[0].object.userData.fbeId != null) {
        this.pushEvent("select_fbe_3d", { id: String(hits[0].object.userData.fbeId) })
      }
    }
    const onMouseMove = (e) => {
      const rect = canvas.getBoundingClientRect()
      if (rect.width <= 0 || rect.height <= 0) return
      mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1
      mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1
    }
    const onResize = () => {
      const w = container.clientWidth || 800
      const h = Math.max(480, container.clientHeight || 480)
      camera.aspect = w / h
      camera.updateProjectionMatrix()
      renderer.setSize(w, h)
    }

    renderer.domElement.addEventListener("pointerdown", onPointerDown)
    renderer.domElement.addEventListener("click", onPointerClick)
    renderer.domElement.addEventListener("mousemove", onMouseMove)
    window.addEventListener("resize", onResize)

    const clock = new THREE.Clock()
    const animate = (time) => {
      this._rafId = requestAnimationFrame(animate)
      const t = clock.getElapsedTime()
      if (this._controls) this._controls.update()

      scene.updateMatrixWorld(true)
      raycaster.setFromCamera(mouse, camera)
      const intersects = raycaster.intersectObjects(safeInteractables, false)
      const selectedId = this.el.dataset.sceneSelected != null && this.el.dataset.sceneSelected !== ""
        ? parseInt(this.el.dataset.sceneSelected, 10)
        : null
      if (intersects.length > 0) {
        const hit = intersects[0].object
        if (this._hoveredObject !== hit) {
          if (this._hoveredObject && this._hoveredObject.material) {
            if (this._hoveredObject.material.emissive && this._hoveredObject.userData.originalHex != null) {
              this._hoveredObject.material.emissive.setHex(this._hoveredObject.userData.originalHex)
            }
          }
          this._hoveredObject = hit
          if (this._hoveredObject.material && this._hoveredObject.material.emissive) {
            this._hoveredObject.material.emissive.setHex(0x334155)
          }
          canvas.style.cursor = "pointer"
          const fbeId = this._hoveredObject.userData && this._hoveredObject.userData.fbeId != null ? this._hoveredObject.userData.fbeId : null
          this.pushEvent("hover_fbe_3d", { id: fbeId != null ? String(fbeId) : null })
        }
      } else {
        if (this._hoveredObject && this._hoveredObject.material) {
          if (this._hoveredObject.material.emissive && (selectedId == null || this._hoveredObject.userData.fbeId !== selectedId)) {
            const hex = this._hoveredObject.userData.originalHex != null ? this._hoveredObject.userData.originalHex : 0
            this._hoveredObject.material.emissive.setHex(hex)
          }
        }
        if (this._hoveredObject !== null) this.pushEvent("hover_fbe_3d", { id: null })
        this._hoveredObject = null
        canvas.style.cursor = "default"
      }

      const delta = clock.getDelta()
      this._applySceneState(time, delta)
      this._applyStateDrivenAnimations(t, delta)

      renderer.render(scene, camera)
    }

    this._rafId = requestAnimationFrame(animate)
    this._cleanup = () => {
      if (this._rafId) cancelAnimationFrame(this._rafId)
      renderer.domElement.removeEventListener("pointerdown", onPointerDown)
      renderer.domElement.removeEventListener("click", onPointerClick)
      renderer.domElement.removeEventListener("mousemove", onMouseMove)
      window.removeEventListener("resize", onResize)
      if (this._controls && this._controls.dispose) this._controls.dispose()
      renderer.dispose()
      if (container && renderer.domElement.parentNode === container) container.removeChild(renderer.domElement)
    }
  },
  updated() {},
  destroyed() {
    if (this._cleanup) this._cleanup()
  },
  _applySceneState(time, _delta) {
    const interactables = this._interactables
    if (!Array.isArray(interactables)) return
    const raw = this.el.dataset.sceneState
    const selectedId = this.el.dataset.sceneSelected != null && this.el.dataset.sceneSelected !== ""
      ? parseInt(this.el.dataset.sceneSelected, 10)
      : null
    const LERP = 0.12
    const THREE = window.THREE
    if (raw) {
      try {
        const state = JSON.parse(raw)
        const list = Array.isArray(state) ? state : (state != null && typeof state === "object" ? Object.values(state) : [])
        this._parsedStateById = {}
        if (Array.isArray(list)) list.forEach((item) => {
          this._parsedStateById[item.id] = item
          const mesh = interactables.find((m) => m.userData && m.userData.fbeId === item.id)
          if (!mesh || !mesh.material) return
          if (mesh.material.color) {
            const targetHex = STATUS_COLORS[item.status] ?? STATUS_COLORS.normal
            if (!mesh.userData._targetColor) mesh.userData._targetColor = new THREE.Color(targetHex)
            mesh.userData._targetColor.setHex(targetHex)
            mesh.material.color.lerp(mesh.userData._targetColor, LERP)
          }
          if (item.facts && mesh.userData) mesh.userData.data = item.facts
          const targetScale = item.status === "active" ? 1 + 0.08 * Math.sin(time * 0.003) : 1
          if (!mesh.userData._targetScaleVec) mesh.userData._targetScaleVec = new THREE.Vector3(1, 1, 1)
          mesh.userData._targetScaleVec.setScalar(targetScale)
          mesh.scale.lerp(mesh.userData._targetScaleVec, LERP)
        })
      } catch (_) {
        this._parsedStateById = {}
      }
    } else {
      this._parsedStateById = {}
    }
    interactables.forEach((mesh) => {
      if (!mesh.material || !mesh.material.emissive) return
      const selected = selectedId != null && mesh.userData.fbeId === selectedId
      if (selected) {
        mesh.material.emissive.setHex(0x115511)
      } else {
        if (this._hoveredObject !== mesh) mesh.material.emissive.setHex(mesh.userData.originalHex != null ? mesh.userData.originalHex : 0)
      }
    })
  },

  _applyStateDrivenAnimations(t, delta) {
    const h = this._stateHandles || {}
    const byId = this._parsedStateById || {}
    const getFact = (id, key) => {
      const item = byId[id]
      if (!item || !item.facts) return undefined
      return item.facts[key]
    }
    const factNum = (id, key) => {
      const v = getFact(id, key)
      if (v === undefined || v === null) return undefined
      const n = parseFloat(String(v), 10)
      return Number.isNaN(n) ? undefined : n
    }
    const factTruthy = (id, key) => {
      const v = getFact(id, key)
      return v === true || v === "true" || v === "on" || v === 1
    }

    if (h.envaseSiren && h.envaseSiren.material) {
      const jam = factTruthy(8, "capper_jam_sens") || (byId[8] && byId[8].status === "warning")
      const intensity = jam ? 0.5 + 0.5 * Math.sin(t * 4) : 0
      h.envaseSiren.material.emissiveIntensity = intensity
    }

    const bottleSpeed = (() => {
      if (factTruthy(8, "capper_jam_sens")) return 0
      const speed = factNum(8, "conveyor_speed")
      if (speed === undefined) return 0.05
      return 0.05 * (Math.min(100, Math.max(0, speed)) / 100)
    })()

    if (h.envaseBottles && Array.isArray(h.envaseBottles)) {
      h.envaseBottles.forEach((b) => {
        b.position.x += bottleSpeed
        if (b.position.x > 8) b.position.x = -8
      })
    }

    if (h.millRotor) {
      const rpm = factNum(1, "motor_rpm")
      const speed = rpm != null && rpm > 0 ? (rpm / 60) * Math.PI * 2 * delta : 0
      h.millRotor.rotation.z += speed
    }

    if (h.filtroPumpGroup) {
      const pumpSpeed = factNum(3, "pump_speed")
      const baseSpeed = pumpSpeed != null && pumpSpeed > 0 ? (pumpSpeed / 50) * delta * 2 : 0
      h.filtroPumpGroup.rotation.y += baseSpeed
    }

    if (h.filtroRakeGroup) {
      const pumpSpeed = factNum(3, "pump_speed")
      const rakeSpeed = pumpSpeed != null && pumpSpeed > 0 ? delta * 0.5 * (pumpSpeed / 80) : 0
      h.filtroRakeGroup.rotation.y += rakeSpeed
    }

    if (h.cipPumpGroup) {
      const pumpOn = factTruthy(9, "cip_pump_state") || (byId[9] && byId[9].status === "active")
      const flowVel = factNum(9, "flow_velocity") || 0
      const rotSpeed = pumpOn ? (2.5 + (flowVel / 10) * 2) * delta : 0
      if (rotSpeed > 0) h.cipPumpGroup.rotation.y += rotSpeed
    }

    if (h.rotorGroup) {
      const gridWarning = byId[11] && byId[11].status === "warning"
      const cost = factNum(11, "grid_power_cost")
      const factor = gridWarning && cost != null && cost > 150 ? 0.2 : 1
      h.rotorGroup.rotation.z -= 0.05 * factor
    }

    if (h.amr) {
      const collision = factTruthy(10, "collision_alert") || (byId[10] && byId[10].status === "warning")
      if (!collision) {
        h.amr.position.x = 20 + Math.sin(t * 0.5) * 15
        h.amr.rotation.y = Math.cos(t * 0.5) > 0 ? 0 : Math.PI
      }
    }

    if (h.steamParticles && Array.isArray(h.steamParticles.children)) {
      const boilTemp = factNum(4, "boil_temp")
      const steamPressure = factNum(4, "steam_pressure")
      const evapRate = factNum(4, "evaporation_rate") || 0
      const tempFactor = boilTemp != null && boilTemp > 80 ? Math.min(1, (boilTemp - 80) / 25) : 0
      const pressureFactor = steamPressure != null && steamPressure > 0 ? Math.min(1, steamPressure / 5) : 0
      const evapFactor = Math.min(1, evapRate / 15)
      const intensity = Math.max(0.2, Math.min(1, tempFactor * 0.6 + pressureFactor * 0.4 + evapFactor * 0.2))
      const rate = 0.003 + intensity * 0.008
      const velScale = 0.5 + intensity * 0.5
      h.steamParticles.children.forEach((p) => {
        p.position.y += (p.userData.velocity || 0.04) * velScale
        p.position.x += (p.userData.xDrift || 0) * velScale
        p.userData.life = (p.userData.life || 0) + rate
        p.material.opacity = 0.5 * (1 - Math.min(1, p.userData.life))
        if (p.userData.life >= 1) {
          p.position.set(15 + (Math.random() - 0.5) * 1.5, 19, -20 + (Math.random() - 0.5) * 1.5)
          p.userData.life = 0
        }
      })
    }

    if (h.mosturaAgitatorGroup) {
      const agitatorOn = factTruthy(2, "agitator_status")
      const rotSpeed = agitatorOn ? delta * 0.8 : 0
      h.mosturaAgitatorGroup.rotation.y += rotSpeed
    }

    if (h.mosturaLiquidTube) {
      const liquidLevel = factNum(2, "liquid_level")
      const level = liquidLevel != null ? Math.max(0.05, Math.min(1, liquidLevel / 100)) : 0.32
      const maxH = h.mosturaLiquidTube.userData.maxLiquidH || 6.4
      h.mosturaLiquidTube.scale.y = level
      h.mosturaLiquidTube.position.y = (maxH / 2) * (level - 1)
    }

    if (h.filtroGrantLiquid && h.filtroGrantLiquid.material) {
      const diffPressure = factNum(3, "diff_pressure")
      const opacity = diffPressure != null ? Math.max(0.3, Math.min(1, 0.3 + (diffPressure - 40) / 200)) : 0.85
      h.filtroGrantLiquid.material.opacity = opacity
    }

    const updateCo2Particles = (particles, fbeId) => {
      if (!particles || !Array.isArray(particles.children)) return
      const pressure = factNum(fbeId, "pressure") || 0
      const co2Flow = factNum(fbeId, "co2_exhaust_flow") || 0
      const intensity = Math.max(0.1, Math.min(1, pressure * 0.5 + (co2Flow / 80) * 0.5))
      const velScale = 0.3 + intensity * 0.7
      const maxH = 14
      particles.children.forEach((p) => {
        p.position.y += (p.userData.velocity || 0.02) * velScale * (delta * 60)
        p.material.opacity = 0.4 * intensity + 0.2
        if (p.position.y > maxH) {
          p.position.y = -2
          p.position.x = (Math.random() - 0.5) * 3
          p.position.z = (Math.random() - 0.5) * 3
        }
      })
    }
    updateCo2Particles(h.fermACo2Particles, 6)
    updateCo2Particles(h.fermBCo2Particles, 7)
  }
}

export default Scene3DHook
