/**
 * FBE_03: Tina Filtro – versão detalhada (tina_filtro_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createFiltro(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(0, 0, -20)

  const matCopper = new THREE.MeshStandardMaterial({ color: 0xc25e1a, roughness: 0.3, metalness: 0.75 })
  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.3, metalness: 0.8 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6, metalness: 0.5 })
  const matMotorBlue = new THREE.MeshStandardMaterial({ color: 0x1d4ed8, roughness: 0.5, metalness: 0.3 })
  const matGlass = new THREE.MeshStandardMaterial({ color: 0xffffff, transparent: true, opacity: 0.25, roughness: 0.1, metalness: 0.9 })
  const matWort = new THREE.MeshStandardMaterial({ color: 0xd97706, roughness: 0.2, transparent: true, opacity: 0.85 })

  const radius = 6.5
  const bodyHeight = 5.5
  const bodyY = 5.5

  const body = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, bodyHeight, 64), matCopper)
  body.position.y = bodyY
  body.castShadow = true
  body.receiveShadow = true
  group.add(body)
  const bottom = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius - 0.2, 0.5, 64), matCopper)
  bottom.position.y = bodyY - bodyHeight / 2 - 0.25
  bottom.castShadow = true
  group.add(bottom)
  const topDome = new THREE.Mesh(new THREE.SphereGeometry(radius, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2.5), matCopper)
  topDome.position.y = bodyY + bodyHeight / 2 - 0.5
  topDome.castShadow = true
  group.add(topDome)

  const legGeo = new THREE.CylinderGeometry(0.5, 0.4, 3, 16)
  const legPositions = [[4.5, 1.5, 4.5], [-4.5, 1.5, 4.5], [4.5, 1.5, -4.5], [-4.5, 1.5, -4.5], [6, 1.5, 0], [-6, 1.5, 0], [0, 1.5, 6], [0, 1.5, -6]]
  for (let i = 0; i < legPositions.length; i++) {
    const pos = legPositions[i]
    const leg = new THREE.Mesh(legGeo, matDarkSteel)
    leg.position.set(pos[0], pos[1], pos[2])
    leg.castShadow = true
    const foot = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 0.2, 16), matDarkSteel)
    foot.position.set(pos[0], 0.1, pos[2])
    group.add(foot, leg)
  }

  const rakeMotorGroup = new THREE.Group()
  rakeMotorGroup.position.set(0, topDome.position.y + radius - 1.2, 0)
  const motorBase = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 1, 32), matSteel)
  motorBase.position.y = 0.5
  motorBase.castShadow = true
  rakeMotorGroup.add(motorBase)
  const gearbox = new THREE.Mesh(new THREE.BoxGeometry(2, 2.5, 2), matDarkSteel)
  gearbox.position.y = 2.25
  gearbox.castShadow = true
  rakeMotorGroup.add(gearbox)
  const motor = new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 2.5, 32), matMotorBlue)
  motor.rotation.z = Math.PI / 2
  motor.position.set(1.5, 2.25, 0)
  motor.castShadow = true
  rakeMotorGroup.add(motor)
  const motorShaft = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 1.5, 16), matSteel)
  motorShaft.position.set(0, 4.25, 0)
  motorShaft.castShadow = true
  rakeMotorGroup.add(motorShaft)
  group.add(rakeMotorGroup)

  const spargePipe = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 4, 16), matSteel)
  spargePipe.position.set(-3.5, topDome.position.y + 3, 0)
  spargePipe.rotation.z = Math.PI / 2
  spargePipe.castShadow = true
  const spargeElbow = new THREE.Mesh(new THREE.SphereGeometry(0.4, 16, 16), matSteel)
  spargeElbow.position.set(-1.5, topDome.position.y + 3, 0)
  const spargeDown = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 1.5, 16), matSteel)
  spargeDown.position.set(-1.5, topDome.position.y + 2.25, 0)
  group.add(spargePipe, spargeElbow, spargeDown)

  const grainDoorGroup = new THREE.Group()
  grainDoorGroup.position.set(0, bodyY - 1.5, radius)
  const doorFrame = new THREE.Mesh(new THREE.BoxGeometry(3.2, 2.2, 0.4), matDarkSteel)
  doorFrame.castShadow = true
  grainDoorGroup.add(doorFrame)
  const grainDoor = new THREE.Mesh(new THREE.BoxGeometry(2.8, 1.8, 0.4), matSteel)
  grainDoor.position.z = 0.1
  grainDoor.castShadow = true
  grainDoorGroup.add(grainDoor)
  const latch = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.8, 8), matDarkSteel)
  latch.rotation.z = Math.PI / 2
  latch.position.set(1.2, 0, 0.35)
  grainDoorGroup.add(latch)
  const chute = new THREE.Mesh(new THREE.BoxGeometry(3.2, 0.2, 2), matSteel)
  chute.position.set(0, -1.2, 1)
  chute.rotation.x = Math.PI / 12
  chute.castShadow = true
  grainDoorGroup.add(chute)
  group.add(grainDoorGroup)

  const grantGroup = new THREE.Group()
  grantGroup.position.set(radius + 1, 3.5, 2)
  const grantBase = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 0.2, 32), matSteel)
  grantBase.position.y = -1
  grantGroup.add(grantBase)
  const grantTop = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 0.2, 32), matSteel)
  grantTop.position.y = 1
  grantGroup.add(grantTop)
  const grantGlass = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 0.7, 2, 32), matGlass)
  grantGroup.add(grantGlass)
  const grantLiquid = new THREE.Mesh(new THREE.CylinderGeometry(0.65, 0.65, 1.5, 32), matWort)
  grantLiquid.position.y = -0.25
  grantGroup.add(grantLiquid)
  const pipeToGrant = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 1.5, 16), matSteel)
  pipeToGrant.rotation.z = Math.PI / 2
  pipeToGrant.position.set(-0.8, -0.5, 0)
  grantGroup.add(pipeToGrant)
  group.add(grantGroup)

  const pumpGroup = new THREE.Group()
  pumpGroup.position.set(0, 1.5, 0)
  const pumpPipe = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 2, 16), matSteel)
  pumpPipe.position.y = 0.5
  pumpGroup.add(pumpPipe)
  const pumpMotor = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 1.5, 16), matMotorBlue)
  pumpMotor.rotation.z = Math.PI / 2
  pumpMotor.position.set(1, -0.5, 0)
  pumpMotor.castShadow = true
  pumpGroup.add(pumpMotor)
  const pumpVolute = new THREE.Mesh(new THREE.SphereGeometry(0.8, 16, 16), matDarkSteel)
  pumpVolute.position.set(0, -0.5, 0)
  pumpGroup.add(pumpVolute)
  group.add(pumpGroup)

  const hitBoxGeo = new THREE.BoxGeometry(15, 20, 15)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 8
  addInteractable(hitBox, 3, "fbe03", "03. Tina_Filtro", { diff_pressure: "59", wort_clarity: "22", sparge_water_temp: "73", rake_height: "64", pump_speed: "67" }, interactablesList)
  group.add(hitBox)

  return { group, filtroPumpGroup: pumpGroup, filtroRakeGroup: rakeMotorGroup, filtroGrantLiquid: grantLiquid }
}

export { createFiltro }
