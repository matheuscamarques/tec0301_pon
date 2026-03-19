/**
 * FBE_09: Sistema CIP – versão detalhada (sistema_cip_3d.html).
 */
import { addInteractable } from "./helpers.js"

function createCIP(THREE, materials, interactablesList) {
  const group = new THREE.Group()
  group.position.set(-30, 0, 10)

  const matSteel = new THREE.MeshStandardMaterial({ color: 0xe2e8f0, roughness: 0.35, metalness: 0.85 })
  const matDarkSteel = new THREE.MeshStandardMaterial({ color: 0x27303f, roughness: 0.6, metalness: 0.5 })
  const matMotor = new THREE.MeshStandardMaterial({ color: 0x1d4ed8, roughness: 0.4, metalness: 0.4 })
  const matCaustic = new THREE.MeshStandardMaterial({ color: 0xef4444, roughness: 0.3, metalness: 0.1 })
  const matAcid = new THREE.MeshStandardMaterial({ color: 0xa855f7, roughness: 0.3, metalness: 0.1 })
  const matWater = new THREE.MeshStandardMaterial({ color: 0x3b82f6, roughness: 0.3, metalness: 0.1 })
  const matGlass = new THREE.MeshStandardMaterial({ color: 0xffffff, transparent: true, opacity: 0.3, roughness: 0.1 })

  const skid = new THREE.Mesh(new THREE.BoxGeometry(14, 0.8, 6), matDarkSteel)
  skid.position.y = 0.4
  skid.castShadow = true
  skid.receiveShadow = true
  group.add(skid)

  const tankRadius = 2
  const tankHeight = 5
  const tankY = 3.5

  function addTank(xPos, zPos, bandMat, liquidMat, liquidPct) {
    const tg = new THREE.Group()
    tg.position.set(xPos, 0, zPos)
    for (let i = 0; i < 4; i++) {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 1, 16), matDarkSteel)
      leg.position.set(Math.cos(i * Math.PI / 2) * 1.4, 1, Math.sin(i * Math.PI / 2) * 1.4)
      tg.add(leg)
    }
    const bottom = new THREE.Mesh(new THREE.SphereGeometry(tankRadius, 32, 16, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), matSteel)
    bottom.position.y = tankY - tankHeight / 2
    tg.add(bottom)
    const body = new THREE.Mesh(new THREE.CylinderGeometry(tankRadius, tankRadius, tankHeight, 64), matSteel)
    body.position.y = tankY
    body.castShadow = true
    tg.add(body)
    const band = new THREE.Mesh(new THREE.CylinderGeometry(tankRadius + 0.05, tankRadius + 0.05, 0.8, 64), bandMat)
    band.position.y = tankY + 1.5
    tg.add(band)
    const dome = new THREE.Mesh(new THREE.SphereGeometry(tankRadius, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2), matSteel)
    dome.position.y = tankY + tankHeight / 2
    tg.add(dome)
    const sgGroup = new THREE.Group()
    sgGroup.position.set(0, tankY, tankRadius + 0.15)
    const sgBg = new THREE.Mesh(new THREE.BoxGeometry(0.4, 4, 0.08), matDarkSteel)
    const sgTube = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 3.8, 16), matGlass)
    sgTube.position.z = 0.08
    sgGroup.add(sgBg, sgTube)
    if (liquidPct > 0) {
      const liqH = 3.8 * (liquidPct / 100)
      const liquid = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, liqH, 16), liquidMat)
      liquid.position.set(0, (-3.8 / 2) + (liqH / 2), 0.08)
      sgGroup.add(liquid)
    }
    tg.add(sgGroup)
    group.add(tg)
  }

  addTank(-4, -0.5, matWater, matWater, 80)
  addTank(0, -0.5, matCaustic, matCaustic, 39)
  addTank(4, -0.5, matAcid, matAcid, 17)

  const pumpGroup = new THREE.Group()
  pumpGroup.position.set(0, 1.5, 2.5)
  const pumpBase = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.5, 2.5), matDarkSteel)
  pumpGroup.add(pumpBase)
  const volute = new THREE.Mesh(new THREE.SphereGeometry(0.8, 24, 24), matDarkSteel)
  volute.position.set(0, 0.8, 0.8)
  volute.scale.z = 0.5
  pumpGroup.add(volute)
  const motor = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 1.5, 32), matMotor)
  motor.rotation.x = Math.PI / 2
  motor.position.set(0, 0.8, -0.4)
  motor.castShadow = true
  pumpGroup.add(motor)
  const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.8, 16), matSteel)
  shaft.rotation.x = Math.PI / 2
  shaft.position.set(0, 0.8, 0.4)
  pumpGroup.add(shaft)
  group.add(pumpGroup)

  const headerPipe = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.35, 12, 16), matSteel)
  headerPipe.rotation.z = Math.PI / 2
  headerPipe.position.set(0, 2, 1.5)
  headerPipe.castShadow = true
  group.add(headerPipe)

  const hitBoxGeo = new THREE.BoxGeometry(16, 10, 8)
  const hitBoxMat = new THREE.MeshBasicMaterial({ visible: false })
  const hitBox = new THREE.Mesh(hitBoxGeo, hitBoxMat)
  hitBox.position.y = 4
  addInteractable(hitBox, 9, "fbe09", "09. Sistema_CIP", { caustic_tank_lvl: "39", acid_tank_lvl: "17", return_conduct: "3", cip_pump_state: "on", flow_velocity: "3" }, interactablesList)
  group.add(hitBox)

  return { group, pumpGroup }
}

export { createCIP }
