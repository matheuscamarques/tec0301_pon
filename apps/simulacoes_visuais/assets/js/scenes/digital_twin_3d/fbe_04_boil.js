/**
 * FBE_04: Caldeira Fervura – versão detalhada (caldeira_fervura_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createBoil(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(15, 0, -20)

  const matCopper = new THREE.MeshStandardMaterial({ color: 0xc25e1a, roughness: 0.25, metalness: 0.85 })
  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.3, metalness: 0.8 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x27303f, roughness: 0.7, metalness: 0.5 })
  const matBurner = new THREE.MeshBasicMaterial({ color: 0xea580c })

  const radius = 5.5
  const burnerBase = new THREE.Mesh(new THREE.CylinderGeometry(radius + 0.2, radius + 0.2, 4, 32), matDarkSteel)
  burnerBase.position.y = 2
  burnerBase.castShadow = true
  group.add(burnerBase)
  const burnerGlow = new THREE.Mesh(new THREE.CylinderGeometry(radius + 0.3, radius + 0.3, 1.5, 32), matBurner)
  burnerGlow.position.y = 2
  group.add(burnerGlow)
  const ventCover = new THREE.Mesh(new THREE.BoxGeometry(3, 2, 0.5), matDarkSteel)
  ventCover.position.set(0, 2, radius + 0.1)
  group.add(ventCover)

  const bodyHeight = 6
  const bodyY = 8
  const body = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, bodyHeight, 64), matCopper)
  body.position.y = bodyY
  body.castShadow = true
  body.receiveShadow = true
  group.add(body)
  const bottomDome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), matCopper)
  bottomDome.position.y = bodyY - bodyHeight / 2
  group.add(bottomDome)
  const topDome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2), matCopper)
  topDome.position.y = bodyY + bodyHeight / 2
  topDome.castShadow = true
  group.add(topDome)

  const chimneyRadius = 0.8
  const chimneyHeight = 8
  const chimney = new THREE.Mesh(new THREE.CylinderGeometry(chimneyRadius, chimneyRadius, chimneyHeight, 32), matSteel)
  chimney.position.y = topDome.position.y + radius + (chimneyHeight / 2) - 1.5
  chimney.castShadow = true
  group.add(chimney)
  const chimneyFlange = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 0.4, 32), matDarkSteel)
  chimneyFlange.position.y = topDome.position.y + radius - 1.5
  group.add(chimneyFlange)

  const manwayGroup = new THREE.Group()
  manwayGroup.position.set(0, bodyY, radius)
  const manwayCollar = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.6, 0.8, 32), matDarkSteel)
  manwayCollar.rotation.x = Math.PI / 2
  manwayCollar.castShadow = true
  const manwayLid = new THREE.Mesh(new THREE.CylinderGeometry(1.7, 1.7, 0.3, 32), matSteel)
  manwayLid.rotation.x = Math.PI / 2
  manwayLid.position.z = 0.4
  manwayLid.castShadow = true
  const manwayHinge = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.8, 0.4), matDarkSteel)
  manwayHinge.position.set(1.6, 0, 0.2)
  manwayGroup.add(manwayCollar, manwayLid, manwayHinge)
  group.add(manwayGroup)

  const doserGroup = new THREE.Group()
  doserGroup.position.set(-radius + 0.5, topDome.position.y + 1, 2)
  doserGroup.rotation.z = Math.PI / 8
  const doserHopper = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 0.4, 3, 16), matSteel)
  doserHopper.position.y = 2
  doserHopper.castShadow = true
  const doserPipe = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 2, 16), matDarkSteel)
  doserPipe.position.y = -0.5
  const doserLid = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.6, 0.1, 16), matDarkSteel)
  doserLid.position.y = 3.5
  doserGroup.add(doserHopper, doserPipe, doserLid)
  group.add(doserGroup)

  const pipeIn = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 4, 16), matSteel)
  pipeIn.position.set(radius + 1, bodyY - 2, 0)
  pipeIn.rotation.z = Math.PI / 2
  pipeIn.castShadow = true
  group.add(pipeIn)
  const pipeOut = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, 3, 16), matSteel)
  pipeOut.position.set(0, 2, -radius - 1)
  pipeOut.rotation.x = Math.PI / 2
  pipeOut.castShadow = true
  group.add(pipeOut)

  const hitBoxGeo = new THREE.BoxGeometry(16, 26, 16)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 12
  addInteractable(hitBox, 4, "fbe04", "04. Caldeira_Fervura", { boil_temp: "79", steam_pressure: "4", evaporation_rate: "9", hop_doser_state: "idle", foam_level: "12" }, interactablesList)
  group.add(hitBox)

  return group
}

export { createBoil }
