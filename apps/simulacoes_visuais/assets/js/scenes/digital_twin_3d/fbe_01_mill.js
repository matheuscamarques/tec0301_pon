/**
 * FBE_01: Moinho de Malte – versão detalhada (moinho_malte_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createMill(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(-30, 0, -20)

  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.3, metalness: 0.8 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.6, metalness: 0.5 })
  const matMotor = new THREE.MeshStandardMaterial({ color: 0x1d4ed8, roughness: 0.4, metalness: 0.6 })
  const matWarning = new THREE.MeshStandardMaterial({ color: 0xf59e0b, roughness: 0.5, metalness: 0.2 })

  const frameGroup = new THREE.Group()
  const legGeo = new THREE.BoxGeometry(0.8, 8, 0.8)
  const legPositions = [[3.5, 4, 2.5], [-3.5, 4, 2.5], [3.5, 4, -2.5], [-3.5, 4, -2.5]]
  for (let i = 0; i < legPositions.length; i++) {
    const pos = legPositions[i]
    const leg = new THREE.Mesh(legGeo, matDarkSteel)
    leg.position.set(pos[0], pos[1], pos[2])
    leg.castShadow = true
    leg.receiveShadow = true
    frameGroup.add(leg)
  }
  const crossGeoX = new THREE.BoxGeometry(7.8, 0.4, 0.4)
  const cross1 = new THREE.Mesh(crossGeoX, matDarkSteel)
  cross1.position.set(0, 2, 2.5)
  const cross2 = new THREE.Mesh(crossGeoX, matDarkSteel)
  cross2.position.set(0, 2, -2.5)
  const crossGeoZ = new THREE.BoxGeometry(0.4, 0.4, 5.8)
  const cross3 = new THREE.Mesh(crossGeoZ, matDarkSteel)
  cross3.position.set(3.5, 2, 0)
  const cross4 = new THREE.Mesh(crossGeoZ, matDarkSteel)
  cross4.position.set(-3.5, 2, 0)
  frameGroup.add(cross1, cross2, cross3, cross4)
  group.add(frameGroup)

  const chamber = new THREE.Mesh(new THREE.BoxGeometry(8, 5, 6), matSteel)
  chamber.position.y = 10.5
  chamber.castShadow = true
  chamber.receiveShadow = true
  group.add(chamber)
  const chamberDoor = new THREE.Mesh(new THREE.BoxGeometry(4, 3, 0.2), matDarkSteel)
  chamberDoor.position.set(0, 10.5, 3.05)
  group.add(chamberDoor)

  const hopperGeo = new THREE.CylinderGeometry(5, 2, 6, 4)
  const hopper = new THREE.Mesh(hopperGeo, matSteel)
  hopper.rotation.y = Math.PI / 4
  hopper.position.y = 16
  hopper.castShadow = true
  group.add(hopper)
  const hopperRim = new THREE.Mesh(new THREE.BoxGeometry(7.5, 0.5, 7.5), matDarkSteel)
  hopperRim.position.y = 18.8
  group.add(hopperRim)
  const inlet = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.5, 2, 16), matDarkSteel)
  inlet.position.y = 20
  group.add(inlet)

  const chute = new THREE.Mesh(new THREE.CylinderGeometry(2, 1, 3, 4), matSteel)
  chute.rotation.y = Math.PI / 4
  chute.position.y = 6.5
  chute.castShadow = true
  group.add(chute)

  const motorGroup = new THREE.Group()
  motorGroup.position.set(4.5, 10.5, 0)
  const motorBody = new THREE.Mesh(new THREE.CylinderGeometry(1.8, 1.8, 4, 32), matMotor)
  motorBody.rotation.x = Math.PI / 2
  motorBody.castShadow = true
  motorGroup.add(motorBody)
  const motorFanCover = new THREE.Mesh(new THREE.CylinderGeometry(1.9, 1.9, 1, 16), matDarkSteel)
  motorFanCover.rotation.x = Math.PI / 2
  motorFanCover.position.z = -2
  motorGroup.add(motorFanCover)
  const motorAxle = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 2, 16), matSteel)
  motorAxle.rotation.x = Math.PI / 2
  motorAxle.position.z = 2
  motorGroup.add(motorAxle)
  group.add(motorGroup)

  const beltGuard = new THREE.Mesh(new THREE.BoxGeometry(1.5, 6, 3), matWarning)
  beltGuard.position.set(4.5, 10.5, 3)
  beltGuard.castShadow = true
  group.add(beltGuard)

  const controlPanel = new THREE.Mesh(new THREE.BoxGeometry(1.5, 2, 1), matDarkSteel)
  controlPanel.position.set(-4.1, 11, 2)
  group.add(controlPanel)
  const led = new THREE.Mesh(new THREE.SphereGeometry(0.15, 8, 8), new THREE.MeshBasicMaterial({ color: 0x10b981 }))
  led.position.set(-4.9, 11.5, 2.3)
  group.add(led)

  const hitBoxGeo = new THREE.BoxGeometry(12, 22, 10)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 11
  addInteractable(hitBox, 1, "fbe01", "01. Moinho_Malte", { motor_rpm: "517", vibration_level: "85", hopper_level: "46", motor_temp: "79", feed_valve_state: "open" }, interactablesList)
  group.add(hitBox)

  return { group, millRotor: motorGroup }
}

export { createMill }
