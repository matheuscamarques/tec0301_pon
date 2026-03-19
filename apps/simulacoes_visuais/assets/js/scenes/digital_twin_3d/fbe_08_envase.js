/**
 * FBE_08: Linha de Envase – versão detalhada (linha_envase_3d.html).
 * Mesma estrutura, dimensões e posições que o documento de exemplo.
 * Retorna { group, bottles } para animação das garrafas no hook.
 */
import { addInteractable } from "./helpers.js"

function createEnvase(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(-10, 0, 25)

  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.35, metalness: 0.85 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6, metalness: 0.4 })
  const matConveyorBelt = new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.9, metalness: 0.1 })
  const matGold = new THREE.MeshStandardMaterial({ color: 0xfbbf24, roughness: 0.3, metalness: 0.8 })
  const matAlarm = new THREE.MeshStandardMaterial({ color: 0xef4444, emissive: 0xef4444, emissiveIntensity: 1 })
  let matGlassAmber
  if (THREE.MeshPhysicalMaterial) {
    matGlassAmber = new THREE.MeshPhysicalMaterial({
      color: 0x92400e,
      transmission: 0.8,
      opacity: 1,
      roughness: 0.1,
      metalness: 0.1,
      ior: 1.5,
      thickness: 0.5
    })
  } else {
    matGlassAmber = new THREE.MeshStandardMaterial({
      color: 0x92400e,
      transparent: true,
      opacity: 0.8,
      roughness: 0.1,
      metalness: 0.1
    })
  }

  const beltLength = 40
  const conveyorFrame = new THREE.Mesh(new THREE.BoxGeometry(beltLength, 1.5, 3.5), matDarkSteel)
  conveyorFrame.position.y = 4
  conveyorFrame.castShadow = true
  conveyorFrame.receiveShadow = true
  group.add(conveyorFrame)

  const belt = new THREE.Mesh(new THREE.BoxGeometry(beltLength + 0.2, 0.2, 3), matConveyorBelt)
  belt.position.y = 4.85
  belt.receiveShadow = true
  group.add(belt)

  const legGeo = new THREE.CylinderGeometry(0.3, 0.3, 4, 16)
  for (let x = -18; x <= 18; x += 9) {
    const legFront = new THREE.Mesh(legGeo, matDarkSteel)
    legFront.position.set(x, 2, 1.5)
    legFront.castShadow = true
    const legBack = new THREE.Mesh(legGeo, matDarkSteel)
    legBack.position.set(x, 2, -1.5)
    legBack.castShadow = true
    group.add(legFront, legBack)
  }

  const railGeo = new THREE.CylinderGeometry(0.1, 0.1, beltLength, 16)
  const railFront = new THREE.Mesh(railGeo, matSteel)
  railFront.rotation.z = Math.PI / 2
  railFront.position.set(0, 5.2, 1.2)
  const railBack = new THREE.Mesh(railGeo, matSteel)
  railBack.rotation.z = Math.PI / 2
  railBack.position.set(0, 5.2, -1.2)
  group.add(railFront, railBack)

  // —— Enchedor (linha_envase_3d.html: fillerGroup) ——
  const fillerGroup = new THREE.Group()
  fillerGroup.position.set(-8, 5, 0)
  const fillerBody = new THREE.Mesh(new THREE.BoxGeometry(6, 6, 5), matSteel)
  fillerBody.position.y = 3
  fillerBody.castShadow = true
  fillerGroup.add(fillerBody)
  const fillerTop = new THREE.Mesh(new THREE.CylinderGeometry(2.5, 3, 2, 32), matSteel)
  fillerTop.position.y = 7
  fillerTop.castShadow = true
  fillerGroup.add(fillerTop)
  const hmiScreen = new THREE.Mesh(new THREE.BoxGeometry(1.5, 1, 0.1), new THREE.MeshBasicMaterial({ color: 0x000000 }))
  hmiScreen.position.set(0, 4, 2.55)
  const hmiError = new THREE.Mesh(new THREE.PlaneGeometry(1.3, 0.8), new THREE.MeshBasicMaterial({ color: 0xef4444 }))
  hmiError.position.set(0, 4, 2.61)
  fillerGroup.add(hmiScreen, hmiError)
  for (let i = -2; i <= 2; i += 1.5) {
    const nozzle = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.1, 2, 16), matSteel)
    nozzle.position.set(i, -0.5, 0)
    nozzle.castShadow = true
    fillerGroup.add(nozzle)
  }
  group.add(fillerGroup)

  // —— Arrolhadora (linha_envase_3d.html: capperGroup) ——
  const capperGroup = new THREE.Group()
  capperGroup.position.set(8, 5, 0)
  const capperBody = new THREE.Mesh(new THREE.BoxGeometry(5, 5, 4.5), matSteel)
  capperBody.position.y = 2.5
  capperBody.castShadow = true
  capperGroup.add(capperBody)
  for (let i = -1; i <= 1; i += 2) {
    const head = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 1.5, 16), matDarkSteel)
    head.position.set(i, 0, 0)
    head.castShadow = true
    capperGroup.add(head)
  }
  const sirenBase = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.2, 16), matDarkSteel)
  sirenBase.position.y = 5.1
  capperGroup.add(sirenBase)
  const sirenLight = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 0.6, 16), matAlarm)
  sirenLight.position.y = 5.5
  capperGroup.add(sirenLight)
  const sensorBox1 = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.4, 0.4), matDarkSteel)
  sensorBox1.position.set(-3, 1, 1.5)
  const sensorLED = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 8), new THREE.MeshBasicMaterial({ color: 0xef4444 }))
  sensorLED.position.set(-3, 1.25, 1.5)
  capperGroup.add(sensorBox1, sensorLED)
  group.add(capperGroup)

  function createBottle(hasCap) {
    const bGroup = new THREE.Group()
    const bBody = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.35, 1.2, 16), matGlassAmber)
    bBody.position.y = 0.6
    bBody.castShadow = true
    const bNeck1 = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.35, 0.5, 16), matGlassAmber)
    bNeck1.position.y = 1.45
    const bNeck2 = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 0.4, 16), matGlassAmber)
    bNeck2.position.y = 1.9
    bGroup.add(bBody, bNeck1, bNeck2)
    const label = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.36, 0.6, 16), matGold)
    label.position.y = 0.6
    bGroup.add(label)
    if (hasCap) {
      const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.14, 0.1, 16), matGold)
      cap.position.y = 2.15
      bGroup.add(cap)
    }
    return bGroup
  }

  const bottles = []
  for (let i = -9.5; i <= -6.5; i += 1.5) {
    const bottle = createBottle(false)
    bottle.position.set(i, 4.95, 0)
    bottles.push(bottle)
    group.add(bottle)
  }
  const jamStartX = 4
  for (let i = 0; i < 8; i++) {
    const bottle = createBottle(false)
    const xOffset = jamStartX + i * 0.45 + (Math.random() * 0.1)
    const zOffset = (Math.random() - 0.5) * 0.8
    bottle.position.set(xOffset, 4.95, zOffset)
    bottles.push(bottle)
    group.add(bottle)
  }
  const stuckBottle = createBottle(true)
  stuckBottle.position.set(8, 4.95, 0)
  stuckBottle.rotation.z = Math.PI / 8
  stuckBottle.rotation.x = Math.PI / 12
  bottles.push(stuckBottle)
  group.add(stuckBottle)
  for (let i = -18; i <= -12; i += 1.5) {
    const bottle = createBottle(false)
    bottle.position.set(i, 4.95, 0)
    bottles.push(bottle)
    group.add(bottle)
  }
  for (let i = 12; i <= 18; i += 2) {
    const bottle = createBottle(true)
    bottle.position.set(i, 4.95, 0)
    bottles.push(bottle)
    group.add(bottle)
  }

  const hitBoxGeo = new THREE.BoxGeometry(42, 12, 6)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 5
  addInteractable(hitBox, 8, "fbe08", "08. Linha_Envase", {
    ir_bottle_detect: "false",
    conveyor_speed: "0",
    fill_head_status: "filling",
    liquid_lvl_detect: "ok",
    capper_jam_sens: "true",
    stop_sensor: "true"
  }, interactablesList)
  group.add(hitBox)

  return { group, bottles, sirenLight }
}

export { createEnvase }
