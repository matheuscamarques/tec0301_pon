/**
 * FBE_07: Fermentador B (Brite) – versão detalhada (fermentador_brite_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createFermentadorB(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(0, 0, 10)

  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.35, metalness: 0.85 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6, metalness: 0.4 })
  const matJacketOff = new THREE.MeshStandardMaterial({ color: 0x94a3b8, roughness: 0.5, metalness: 0.5 })

  const radius = 5
  const cylHeight = 11
  const cylY = 11
  const legGeo = new THREE.CylinderGeometry(0.35, 0.25, 6, 16)
  const legPositions = [[3.8, 3, 3.8], [-3.8, 3, 3.8], [3.8, 3, -3.8], [-3.8, 3, -3.8]]
  for (let i = 0; i < legPositions.length; i++) {
    const pos = legPositions[i]
    const leg = new THREE.Mesh(legGeo, matDarkSteel)
    leg.position.set(pos[0], pos[1], pos[2])
    leg.castShadow = true
    const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 0.2, 16), matDarkSteel)
    foot.position.set(pos[0], 0.1, pos[2])
    group.add(foot, leg)
  }

  const bottomDome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), matSteel)
  bottomDome.position.y = cylY - cylHeight / 2
  bottomDome.castShadow = true
  group.add(bottomDome)

  const cylinder = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, cylHeight, 64), matSteel)
  cylinder.position.y = cylY
  cylinder.castShadow = true
  cylinder.receiveShadow = true
  group.add(cylinder)

  const domeY = cylY + cylHeight / 2
  const dome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2), matSteel)
  dome.position.y = domeY
  dome.castShadow = true
  group.add(dome)

  const jacket1 = new THREE.Mesh(new THREE.CylinderGeometry(radius + 0.05, radius + 0.05, 3.5, 64), matJacketOff)
  jacket1.position.y = cylY - 2.5
  group.add(jacket1)
  const jacket2 = new THREE.Mesh(new THREE.CylinderGeometry(radius + 0.05, radius + 0.05, 3.5, 64), matJacketOff)
  jacket2.position.y = cylY + 2.5
  group.add(jacket2)

  const sgGroup = new THREE.Group()
  sgGroup.position.set(radius * 0.75, cylY, radius * 0.75)
  sgGroup.rotation.y = Math.PI / 4
  const sgBg = new THREE.Mesh(new THREE.BoxGeometry(0.8, 9, 0.2), matDarkSteel)
  sgBg.castShadow = true
  const sgTube = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 8.5, 16), new THREE.MeshStandardMaterial({ color: 0xffffff, transparent: true, opacity: 0.3, roughness: 0.1 }))
  sgTube.position.z = 0.2
  const sgLiquid = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 6, 16), new THREE.MeshStandardMaterial({ color: 0xfbbf24, roughness: 0.2 }))
  sgLiquid.position.set(0, -1.25, 0.2)
  const connTop = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.8, 16), matDarkSteel)
  connTop.rotation.x = Math.PI / 2
  connTop.position.set(0, 4.25, -0.2)
  const connBot = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.8, 16), matDarkSteel)
  connBot.rotation.x = Math.PI / 2
  connBot.position.set(0, -4.25, -0.2)
  sgGroup.add(sgBg, sgTube, sgLiquid, connTop, connBot)
  group.add(sgGroup)

  const manwayGroup = new THREE.Group()
  manwayGroup.position.set(0, cylY - 4, radius)
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

  const hitBoxGeo = new THREE.CylinderGeometry(6, 6, 18, 16)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 11
  addInteractable(hitBox, 7, "fbe07", "07. Fermentador_B", { internal_temp: "21", pressure: "0", gravity_brix: "16", glycol_jacket_st: "off", co2_exhaust_flow: "45", ferm_phase: "growth" }, interactablesList)
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

export { createFermentadorB }
