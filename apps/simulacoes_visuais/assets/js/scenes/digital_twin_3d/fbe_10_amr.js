/**
 * FBE_10: Frota AMR – versão detalhada (frota_amr_3d.html).
 * Retorna o grupo do AMR para o hook animar position/rotation.
 */
import { addInteractable } from "./helpers.js"

function createAMR(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(30, 0.5, 20)

  const matAmrBody = new THREE.MeshStandardMaterial({ color: 0x334155, roughness: 0.4, metalness: 0.6 })
  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.3, metalness: 0.8 })
  const matWheel = new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.9 })
  const matLidar = new THREE.MeshStandardMaterial({ color: 0x000000, roughness: 0.1, metalness: 0.9 })
  const matCrate = new THREE.MeshStandardMaterial({ color: 0x92400e, roughness: 0.8 })
  const matAmber = new THREE.MeshStandardMaterial({ color: 0xf59e0b, emissive: 0xf59e0b, emissiveIntensity: 1 })
  const matBarrel = new THREE.MeshStandardMaterial({ color: 0x475569, roughness: 0.5, metalness: 0.5 })

  const bodyLower = new THREE.Mesh(new THREE.BoxGeometry(4, 1.2, 3), matAmrBody)
  bodyLower.position.y = 1
  bodyLower.castShadow = true
  group.add(bodyLower)
  const bodyUpper = new THREE.Mesh(new THREE.BoxGeometry(3, 0.8, 2.5), matAmrBody)
  bodyUpper.position.y = 2
  bodyUpper.castShadow = true
  group.add(bodyUpper)

  const wheelGeo = new THREE.CylinderGeometry(0.5, 0.5, 0.5, 32)
  const wheelPositions = [[1.2, 0.6, 1.6], [-1.2, 0.6, 1.6], [1.2, 0.6, -1.6], [-1.2, 0.6, -1.6]]
  for (let i = 0; i < wheelPositions.length; i++) {
    const pos = wheelPositions[i]
    const w = new THREE.Mesh(wheelGeo, matWheel)
    w.rotation.x = Math.PI / 2
    w.position.set(pos[0], pos[1], pos[2])
    w.castShadow = true
    group.add(w)
  }

  const lidarBase = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.4, 32), matLidar)
  lidarBase.position.y = 2.6
  group.add(lidarBase)
  const lidarScanner = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.3, 32), matLidar)
  lidarScanner.position.y = 2.95
  group.add(lidarScanner)

  const statusLightGeo = new THREE.BoxGeometry(0.15, 0.4, 1)
  const lightL = new THREE.Mesh(statusLightGeo, matAmber)
  lightL.position.set(-2, 1.2, 0)
  const lightR = new THREE.Mesh(statusLightGeo, matAmber)
  lightR.position.set(2, 1.2, 0)
  group.add(lightL, lightR)

  const payloadGroup = new THREE.Group()
  payloadGroup.position.y = 2.2
  const palletBase = new THREE.Mesh(new THREE.BoxGeometry(3.5, 0.3, 2.8), matCrate)
  palletBase.position.y = 0.15
  payloadGroup.add(palletBase)
  const barrelGeo = new THREE.CylinderGeometry(0.7, 0.7, 1.5, 16)
  const barrelPositions = [[0.8, 0.9, 0.6], [-0.8, 0.9, 0.6], [0.8, 0.9, -0.6], [-0.8, 0.9, -0.6]]
  for (let i = 0; i < barrelPositions.length; i++) {
    const b = new THREE.Mesh(barrelGeo, matBarrel)
    b.position.set(barrelPositions[i][0], barrelPositions[i][1], barrelPositions[i][2])
    b.castShadow = true
    payloadGroup.add(b)
  }
  group.add(payloadGroup)

  const hitBoxGeo = new THREE.BoxGeometry(5, 3, 4)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 2
  addInteractable(hitBox, 10, "fbe10", "10. Frota_AMR", { robot_1_battery: "25", robot_1_location: "{0, 0}", robot_1_status: "recalculando_rota", collision_alert: "false", payload_weight: "368" }, interactablesList)
  group.add(hitBox)

  return group
}

export { createAMR }
