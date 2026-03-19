/**
 * FBE_11: Smart Grid – versão completa do smart_grid_3d.html.
 * Inclui: turbina eólica, painéis solares, ESS (bateria), subestação.
 * Retorna { group, rotorGroup } para animação do rotor no hook.
 */
import { addInteractable } from "./helpers.js"

function createTurbine(THREE, materials, interactablesList) {
  const gridGroup = new THREE.Group()
  gridGroup.position.set(58, 0, -42)

  const matSteel = new THREE.MeshStandardMaterial({ color: 0x94a3b8, roughness: 0.3, metalness: 0.8 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6, metalness: 0.5 })
  const matSolar = new THREE.MeshStandardMaterial({ color: 0x1e3a8a, roughness: 0.2, metalness: 0.5 })
  const matBattery = new THREE.MeshStandardMaterial({ color: 0x475569, roughness: 0.5 })
  const matAlert = new THREE.MeshStandardMaterial({ color: 0xef4444, emissive: 0xef4444, emissiveIntensity: 1 })

  // —— Turbina eólica (como no documento) ——
  const turbineGroup = new THREE.Group()
  turbineGroup.position.set(-15, 0, -10)
  const mast = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 1.2, 25, 16), matSteel)
  mast.position.y = 12.5
  mast.castShadow = true
  turbineGroup.add(mast)
  const nacelle = new THREE.Mesh(new THREE.BoxGeometry(2, 2, 4), matSteel)
  nacelle.position.set(0, 25, 0)
  turbineGroup.add(nacelle)
  const rotorGroup = new THREE.Group()
  rotorGroup.position.set(0, 25, 2.2)
  const hub = new THREE.Mesh(new THREE.SphereGeometry(0.8, 16, 16), matSteel)
  rotorGroup.add(hub)
  for (let i = 0; i < 3; i++) {
    const blade = new THREE.Mesh(new THREE.BoxGeometry(0.2, 10, 0.8), matSteel)
    blade.position.y = 5
    const pivot = new THREE.Group()
    pivot.rotation.z = (Math.PI * 2 / 3) * i
    pivot.add(blade)
    rotorGroup.add(pivot)
  }
  turbineGroup.add(rotorGroup)
  gridGroup.add(turbineGroup)

  // —— Painéis solares (2 linhas x 3 colunas) ——
  const solarGroup = new THREE.Group()
  solarGroup.position.set(15, 0, -10)
  for (let row = 0; row < 2; row++) {
    for (let col = 0; col < 3; col++) {
      const pFrame = new THREE.Mesh(new THREE.BoxGeometry(4, 0.2, 6), matDarkSteel)
      const pCells = new THREE.Mesh(new THREE.PlaneGeometry(3.8, 5.8), matSolar)
      pCells.rotation.x = -Math.PI / 2
      pCells.position.y = 0.11
      const panel = new THREE.Group()
      panel.add(pFrame, pCells)
      panel.rotation.x = -Math.PI / 6
      panel.position.set(col * 5 - 5, 2, row * 7)
      solarGroup.add(panel)
      const pLeg = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 2, 8), matDarkSteel)
      pLeg.position.set(col * 5 - 5, 1, row * 7)
      solarGroup.add(pLeg)
    }
  }
  gridGroup.add(solarGroup)

  // —— ESS (Energy Storage System / Bateria) ——
  const essGroup = new THREE.Group()
  essGroup.position.set(-10, 0, 15)
  const batteryContainer = new THREE.Mesh(new THREE.BoxGeometry(8, 5, 4), matBattery)
  batteryContainer.position.y = 2.5
  batteryContainer.castShadow = true
  essGroup.add(batteryContainer)
  const ledStrip = new THREE.Mesh(new THREE.BoxGeometry(0.2, 1.5, 0.5), matAlert)
  ledStrip.position.set(4.05, 3, 1)
  essGroup.add(ledStrip)
  const vent = new THREE.Mesh(new THREE.BoxGeometry(6, 1, 0.2), matDarkSteel)
  vent.position.set(0, 1.5, 2.01)
  essGroup.add(vent)
  gridGroup.add(essGroup)

  // —— Subestação ——
  const subStation = new THREE.Group()
  subStation.position.set(12, 0, 15)
  const subBody = new THREE.Mesh(new THREE.BoxGeometry(6, 4, 6), matDarkSteel)
  subBody.position.y = 2
  subStation.add(subBody)
  const insulatorGeo = new THREE.CylinderGeometry(0.2, 0.4, 1.5, 8)
  for (let i = -1; i <= 1; i++) {
    const ins = new THREE.Mesh(insulatorGeo, matSteel)
    ins.position.set(i * 1.5, 4.5, 0)
    subStation.add(ins)
  }
  gridGroup.add(subStation)

  // —— Hitbox única para todo o Smart Grid (como no documento) ——
  const hitBoxGeo = new THREE.BoxGeometry(45, 30, 45)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 10
  addInteractable(hitBox, 11, "fbe11", "11. Smart_Grid", { grid_power_cost: "161", v2g_battery_lvl: "16", main_load_draw: "73", grid_fault_detec: "false" }, interactablesList)
  gridGroup.add(hitBox)

  return { group: gridGroup, rotorGroup }
}

export { createTurbine }
