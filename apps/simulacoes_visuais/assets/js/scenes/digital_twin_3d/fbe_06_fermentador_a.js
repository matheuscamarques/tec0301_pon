/**
 * FBE_06: Fermentador A (Cónico) – versão detalhada (fermentador_conico_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createFermentadorA(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(15, 0, 10)

  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.35, metalness: 0.85 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6, metalness: 0.4 })
  const matJacketOff = new THREE.MeshStandardMaterial({ color: 0x94a3b8, roughness: 0.5, metalness: 0.5 })

  const radius = 5
  const cylHeight = 10
  const coneHeight = 6
  const legGeo = new THREE.CylinderGeometry(0.35, 0.25, 8, 16)
  const legPositions = [[3.8, 4, 3.8], [-3.8, 4, 3.8], [3.8, 4, -3.8], [-3.8, 4, -3.8]]
  for (let i = 0; i < legPositions.length; i++) {
    const pos = legPositions[i]
    const leg = new THREE.Mesh(legGeo, matDarkSteel)
    leg.position.set(pos[0], pos[1], pos[2])
    leg.castShadow = true
    const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 0.2, 16), matDarkSteel)
    foot.position.set(pos[0], 0.1, pos[2])
    group.add(foot, leg)
  }

  const coneY = 8
  const coneGeo = new THREE.ConeGeometry(radius, coneHeight, 64)
  const cone = new THREE.Mesh(coneGeo, matSteel)
  cone.rotation.x = Math.PI
  cone.position.y = coneY - (coneHeight / 2)
  cone.castShadow = true
  cone.receiveShadow = true
  group.add(cone)

  const cylY = coneY + (cylHeight / 2)
  const cylinder = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, cylHeight, 64), matSteel)
  cylinder.position.y = cylY
  cylinder.castShadow = true
  cylinder.receiveShadow = true
  group.add(cylinder)

  const domeY = coneY + cylHeight
  const dome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2), matSteel)
  dome.position.y = domeY
  dome.castShadow = true
  group.add(dome)

  const jacket1 = new THREE.Mesh(new THREE.CylinderGeometry(radius + 0.05, radius + 0.05, 3, 64), matJacketOff)
  jacket1.position.y = cylY - 2
  group.add(jacket1)
  const jacket2 = new THREE.Mesh(new THREE.CylinderGeometry(radius + 0.05, radius + 0.05, 3, 64), matJacketOff)
  jacket2.position.y = cylY + 2
  group.add(jacket2)
  const jacketCone = new THREE.Mesh(new THREE.ConeGeometry(radius * 0.7, coneHeight * 0.6, 64), matJacketOff)
  jacketCone.rotation.x = Math.PI
  jacketCone.position.y = coneY - (coneHeight * 0.4)
  group.add(jacketCone)

  const manwayGroup = new THREE.Group()
  manwayGroup.position.set(0, cylY - 3, radius)
  const manwayCollar = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, 0.4, 32), matDarkSteel)
  manwayCollar.rotation.x = Math.PI / 2
  manwayCollar.castShadow = true
  const manwayLid = new THREE.Mesh(new THREE.CylinderGeometry(1.3, 1.3, 0.1, 32), matSteel)
  manwayLid.rotation.x = Math.PI / 2
  manwayLid.position.z = 0.2
  manwayLid.castShadow = true
  const hinge = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.8, 0.3), matDarkSteel)
  hinge.position.set(1.3, 0, 0.1)
  manwayGroup.add(manwayCollar, manwayLid, hinge)
  group.add(manwayGroup)

  const pipeRadius = 0.25
  const pipeVert = new THREE.Mesh(new THREE.CylinderGeometry(pipeRadius, pipeRadius, cylHeight + 4, 16), matSteel)
  pipeVert.position.set(radius + 0.8, cylY + 1, 0)
  pipeVert.castShadow = true
  group.add(pipeVert)
  const topElbow = new THREE.Mesh(new THREE.CylinderGeometry(pipeRadius, pipeRadius, 2, 16), matSteel)
  topElbow.rotation.z = Math.PI / 2
  topElbow.position.set(radius - 0.2, domeY + radius + 0.5, 0)
  group.add(topElbow)
  const pipeToDome = new THREE.Mesh(new THREE.CylinderGeometry(pipeRadius, pipeRadius, 1, 16), matSteel)
  pipeToDome.position.set(0, domeY + radius, 0)
  group.add(pipeToDome)

  const prvAssembly = new THREE.Group()
  prvAssembly.position.set(radius + 0.8, cylY - 2, 0)
  const prvValve = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.8, 16), matDarkSteel)
  prvValve.rotation.z = Math.PI / 2
  prvValve.position.set(0.6, 0, 0)
  prvAssembly.add(prvValve)
  const exhaustPipe = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 1.5, 16), matSteel)
  exhaustPipe.position.set(1.2, -0.75, 0)
  prvAssembly.add(exhaustPipe)
  group.add(prvAssembly)

  const bottomValve = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 1, 16), matSteel)
  bottomValve.position.set(0, coneY - coneHeight - 0.5, 0)
  group.add(bottomValve)
  const rackArm = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.25, 1.5, 16), matSteel)
  rackArm.rotation.z = Math.PI / 2
  rackArm.position.set(0.8, coneY - coneHeight + 1.5, 0)
  group.add(rackArm)

  const hitBoxGeo = new THREE.CylinderGeometry(6, 6, 18, 16)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 10
  addInteractable(hitBox, 6, "fbe06", "06. Fermentador_A", { internal_temp: "22", pressure: "0", gravity_brix: "13", glycol_jacket_st: "off", co2_exhaust_flow: "26", ferm_phase: "growth" }, interactablesList)
  group.add(hitBox)

  const co2Particles = new THREE.Group()
  co2Particles.position.y = 2
  const bubbleGeo = new THREE.SphereGeometry(0.15, 8, 8)
  const bubbleMat = new THREE.MeshBasicMaterial({ color: 0xe0f2fe, transparent: true, opacity: 0.7 })
  const maxH = 14
  for (let i = 0; i < 8; i++) {
    const bubble = new THREE.Mesh(bubbleGeo, bubbleMat.clone())
    bubble.position.set((Math.random() - 0.5) * 3, (i / 8) * maxH - 2, (Math.random() - 0.5) * 3)
    bubble.userData = { baseY: bubble.position.y, velocity: 0.02 + Math.random() * 0.02, life: Math.random() }
    co2Particles.add(bubble)
  }
  group.add(co2Particles)

  return { group, co2Particles }
}

export { createFermentadorA }
