/**
 * FBE_02: Tanque Mostura – versão detalhada (tanque_mostura_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createMostura(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(-15, 0, -20)

  const matCopper = new THREE.MeshStandardMaterial({ color: 0xc25e1a, roughness: 0.25, metalness: 0.85 })
  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.3, metalness: 0.8 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6, metalness: 0.5 })
  const matMotorBlue = new THREE.MeshStandardMaterial({ color: 0x1d4ed8, roughness: 0.5, metalness: 0.3 })
  const matGlass = new THREE.MeshStandardMaterial({ color: 0xffffff, transparent: true, opacity: 0.3, roughness: 0.1 })
  const matLiquid = new THREE.MeshStandardMaterial({ color: 0x78350f, roughness: 0.2, transparent: true, opacity: 0.9 })

  const radius = 5
  const bodyHeight = 8
  const bodyY = 7

  const body = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, bodyHeight, 64), matCopper)
  body.position.y = bodyY
  body.castShadow = true
  body.receiveShadow = true
  group.add(body)

  const topDome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2), matCopper)
  topDome.position.y = bodyY + bodyHeight / 2
  topDome.castShadow = true
  group.add(topDome)

  const bottomDome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), matCopper)
  bottomDome.position.y = bodyY - bodyHeight / 2
  bottomDome.castShadow = true
  group.add(bottomDome)

  const legGeo = new THREE.CylinderGeometry(0.4, 0.4, 4, 16)
  const legPositions = [[3.5, 2, 3.5], [-3.5, 2, 3.5], [3.5, 2, -3.5], [-3.5, 2, -3.5]]
  for (let i = 0; i < legPositions.length; i++) {
    const pos = legPositions[i]
    const leg = new THREE.Mesh(legGeo, matDarkSteel)
    leg.position.set(pos[0], pos[1], pos[2])
    leg.castShadow = true
    const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 0.2, 16), matDarkSteel)
    foot.position.set(pos[0], 0.1, pos[2])
    group.add(foot, leg)
  }

  const agitatorGroup = new THREE.Group()
  agitatorGroup.position.set(0, topDome.position.y + radius, 0)
  const gearbox = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, 1.5, 32), matDarkSteel)
  gearbox.position.y = 0.75
  gearbox.castShadow = true
  agitatorGroup.add(gearbox)
  const motor = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 2, 32), matMotorBlue)
  motor.position.y = 2.5
  motor.castShadow = true
  agitatorGroup.add(motor)
  const motorShaft = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 1, 16), matSteel)
  motorShaft.position.y = 3.8
  motorShaft.castShadow = true
  const fan = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.1, 0.4), matDarkSteel)
  fan.position.y = 0.4
  motorShaft.add(fan)
  agitatorGroup.add(motorShaft)
  group.add(agitatorGroup)

  const gristPipe = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 4, 32), matSteel)
  gristPipe.position.set(-3, topDome.position.y + 2, 0)
  gristPipe.rotation.z = Math.PI / 6
  gristPipe.castShadow = true
  group.add(gristPipe)
  const hopperFlange = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 0.2, 32), matDarkSteel)
  hopperFlange.position.set(-3.9, topDome.position.y + 3.6, 0)
  hopperFlange.rotation.z = Math.PI / 6
  group.add(hopperFlange)
  const waterPipe = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 2, 16), matSteel)
  waterPipe.position.set(-2.5, topDome.position.y + 3, 1)
  waterPipe.rotation.x = Math.PI / 2
  group.add(waterPipe)

  const manwayBase = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 0.5, 32), matDarkSteel)
  manwayBase.position.set(2, topDome.position.y + 1.5, 2)
  manwayBase.rotation.x = Math.PI / 6
  manwayBase.rotation.z = -Math.PI / 6
  manwayBase.castShadow = true
  const manwayLid = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.6, 0.2, 32), matSteel)
  manwayLid.position.set(2.1, topDome.position.y + 1.8, 2.1)
  manwayLid.rotation.x = Math.PI / 6
  manwayLid.rotation.z = -Math.PI / 6
  manwayLid.castShadow = true
  const manwayHandle = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.4, 1.5), matDarkSteel)
  manwayHandle.position.set(0, 0.2, 0)
  manwayLid.add(manwayHandle)
  group.add(manwayBase, manwayLid)

  const sightGroup = new THREE.Group()
  sightGroup.position.set(4.8, bodyY, 1.5)
  sightGroup.rotation.y = Math.PI / 4
  const glassFrame = new THREE.Mesh(new THREE.BoxGeometry(0.8, 7, 0.2), matDarkSteel)
  sightGroup.add(glassFrame)
  const glassTube = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 6.5, 16), matGlass)
  glassTube.position.z = 0.2
  sightGroup.add(glassTube)
  const maxLiquidH = 6.4
  const liquidTube = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, maxLiquidH, 16), matLiquid)
  liquidTube.position.y = 0
  liquidTube.position.z = 0.2
  liquidTube.scale.y = 0.32
  liquidTube.userData.maxLiquidH = maxLiquidH
  sightGroup.add(liquidTube)
  const connectionTop = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.6, 8), matDarkSteel)
  connectionTop.rotation.x = Math.PI / 2
  connectionTop.position.set(0, 3.25, -0.2)
  const connectionBot = connectionTop.clone()
  connectionBot.position.set(0, -3.25, -0.2)
  sightGroup.add(connectionTop, connectionBot)
  group.add(sightGroup)

  const outletPipe = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 2, 16), matSteel)
  outletPipe.position.set(0, 1.5, 0)
  group.add(outletPipe)
  const valve = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1), matDarkSteel)
  valve.position.set(0, 1, 0)
  const valveHandle = new THREE.Mesh(new THREE.BoxGeometry(0.2, 1.5, 0.2), new THREE.MeshStandardMaterial({ color: 0xef4444 }))
  valveHandle.position.set(0.6, 0, 0)
  valve.add(valveHandle)
  group.add(valve)

  const hitBoxGeo = new THREE.BoxGeometry(11, 22, 11)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 10
  addInteractable(hitBox, 2, "fbe02", "02. Tanque_Mostura", { mash_temp: "62", water_flow_rate: "42", agitator_status: "on", ph_level: "53", viscosity: "19", liquid_level: "32" }, interactablesList)
  group.add(hitBox)

  return { group, agitatorGroup, mosturaLiquidTube: liquidTube }
}

export { createMostura }
