/**
 * FBE_05: Trocador de Calor – versão detalhada (trocador_calor_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createHeatExchanger(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(25, 2.5, -10)

  const baseMat = new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.9 })
  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.4, metalness: 0.7 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.6, metalness: 0.4 })
  const matPipeWort = new THREE.MeshStandardMaterial({ color: 0xd97706, roughness: 0.3, metalness: 0.6 })
  const matPipeGlycol = new THREE.MeshStandardMaterial({ color: 0x3b82f6, roughness: 0.3, metalness: 0.6 })
  const matPipeHotWater = new THREE.MeshStandardMaterial({ color: 0xef4444, roughness: 0.3 })

  const heBase = new THREE.Mesh(new THREE.BoxGeometry(6, 1, 14), baseMat)
  heBase.position.y = 0.5
  heBase.castShadow = true
  heBase.receiveShadow = true
  group.add(heBase)

  const frameWidth = 4.5
  const frameHeight = 9
  const frameDepth = 1.2
  const frameY = 5.5

  const frontPlate = new THREE.Mesh(new THREE.BoxGeometry(frameWidth, frameHeight, frameDepth), matDarkSteel)
  frontPlate.position.set(0, frameY, 6)
  frontPlate.castShadow = true
  const backPlate = new THREE.Mesh(new THREE.BoxGeometry(frameWidth, frameHeight, frameDepth), matDarkSteel)
  backPlate.position.set(0, frameY, -6)
  backPlate.castShadow = true
  group.add(frontPlate, backPlate)

  const barGeo = new THREE.CylinderGeometry(0.2, 0.2, 13, 16)
  const topBar = new THREE.Mesh(barGeo, matSteel)
  topBar.rotation.x = Math.PI / 2
  topBar.position.set(0, frameY + 3.8, 0)
  topBar.castShadow = true
  const botBar = new THREE.Mesh(barGeo, matSteel)
  botBar.rotation.x = Math.PI / 2
  botBar.position.set(0, frameY - 3.8, 0)
  botBar.castShadow = true
  const sideBar1 = new THREE.Mesh(barGeo, matSteel)
  sideBar1.rotation.x = Math.PI / 2
  sideBar1.position.set(1.8, frameY, 0)
  const sideBar2 = new THREE.Mesh(barGeo, matSteel)
  sideBar2.rotation.x = Math.PI / 2
  sideBar2.position.set(-1.8, frameY, 0)
  group.add(topBar, botBar, sideBar1, sideBar2)

  const plateWidth = 4
  const plateHeight = 7.6
  const plateThickness = 0.1
  const numPlates = 24
  const gap = 0.25
  const plateGeo = new THREE.BoxGeometry(plateWidth, plateHeight, plateThickness)
  for (let i = 0; i < numPlates; i++) {
    const plate = new THREE.Mesh(plateGeo, matSteel)
    const zPos = -5 + (i * gap)
    plate.position.set(0, frameY, zPos)
    plate.castShadow = true
    group.add(plate)
  }

  const portRadius = 0.6
  const portLength = 2
  const portGeo = new THREE.CylinderGeometry(portRadius, portRadius, portLength, 32)
  const portWortIn = new THREE.Mesh(portGeo, matPipeWort)
  portWortIn.rotation.x = Math.PI / 2
  portWortIn.position.set(-1.2, frameY + 2.5, 6 + portLength / 2)
  portWortIn.castShadow = true
  const portWortOut = new THREE.Mesh(portGeo, matPipeWort)
  portWortOut.rotation.x = Math.PI / 2
  portWortOut.position.set(-1.2, frameY - 2.5, 6 + portLength / 2)
  portWortOut.castShadow = true
  const portGlycolIn = new THREE.Mesh(portGeo, matPipeGlycol)
  portGlycolIn.rotation.x = Math.PI / 2
  portGlycolIn.position.set(1.2, frameY - 2.5, 6 + portLength / 2)
  portGlycolIn.castShadow = true
  const portWaterOut = new THREE.Mesh(portGeo, matPipeHotWater)
  portWaterOut.rotation.x = Math.PI / 2
  portWaterOut.position.set(1.2, frameY + 2.5, 6 + portLength / 2)
  portWaterOut.castShadow = true
  const flangeGeo = new THREE.CylinderGeometry(0.8, 0.8, 0.2, 32)
  const ports = [portWortIn, portWortOut, portGlycolIn, portWaterOut]
  for (let i = 0; i < ports.length; i++) {
    const flange = new THREE.Mesh(flangeGeo, matDarkSteel)
    flange.rotation.x = Math.PI / 2
    flange.position.copy(ports[i].position)
    flange.position.z += portLength / 2 - 0.1
    group.add(flange)
  }
  group.add(portWortIn, portWortOut, portGlycolIn, portWaterOut)

  const hitBoxGeo = new THREE.BoxGeometry(8, 12, 16)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 5.5
  addInteractable(hitBox, 5, "fbe05", "05. Trocador_Calor", { wort_in_temp: "11", wort_out_temp: "11", glycol_valve_pos: "40", water_pressure: "3" }, interactablesList)
  group.add(hitBox)

  return group
}

export { createHeatExchanger }
