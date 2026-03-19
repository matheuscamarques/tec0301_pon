/**
 * Pipes between FBEs – detalhado: tubos, flanges, cotovelos, válvulas e suportes.
 */
const TUBE_RADIUS = 0.28
const FLANGE_RADIUS = 0.5
const FLANGE_HEIGHT = 0.12
const JOINT_RADIUS = 0.38
const VALVE_SIZE = 0.35

function createPipes(THREE, factoryGroup, materials) {
  const matSteel = materials.matSteel || new THREE.MeshStandardMaterial({ color: 0x94a3b8, roughness: 0.3, metalness: 0.8 })
  const matDarkSteel = materials.matDarkSteel || new THREE.MeshStandardMaterial({ color: 0x475569, roughness: 0.5, metalness: 0.7 })

  /** Tubo reto com flanges nas pontas. */
  function pipeSegment(p1, p2, material) {
    const path = new THREE.LineCurve3(p1.clone(), p2.clone())
    const tube = new THREE.Mesh(
      new THREE.TubeGeometry(path, 12, TUBE_RADIUS, 12, false),
      material
    )
    tube.castShadow = true
    factoryGroup.add(tube)
    const flangeGeo = new THREE.CylinderGeometry(FLANGE_RADIUS, FLANGE_RADIUS, FLANGE_HEIGHT, 16)
    const f1 = new THREE.Mesh(flangeGeo, matDarkSteel)
    f1.position.copy(p1)
    alignCylinderToSegment(f1, p1, p2)
    f1.castShadow = true
    factoryGroup.add(f1)
    const f2 = new THREE.Mesh(flangeGeo, matDarkSteel)
    f2.position.copy(p2)
    alignCylinderToSegment(f2, p2, p1)
    f2.castShadow = true
    factoryGroup.add(f2)
  }

  function alignCylinderToSegment(mesh, from, to) {
    const dir = new THREE.Vector3().subVectors(to, from).normalize()
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir)
  }

  /** Junção esférica (cotovelo visual) no ponto. */
  function joint(pos, material) {
    const s = new THREE.Mesh(new THREE.SphereGeometry(JOINT_RADIUS, 12, 12), material)
    s.position.copy(pos)
    s.castShadow = true
    factoryGroup.add(s)
  }

  /** Válvula (corpo + volante) ao longo do segmento, em t (0..1). */
  function valveOnSegment(p1, p2, t, material) {
    const pos = new THREE.Vector3().lerpVectors(p1, p2, t)
    const dir = new THREE.Vector3().subVectors(p2, p1).normalize()
    const box = new THREE.Mesh(new THREE.BoxGeometry(VALVE_SIZE, VALVE_SIZE * 1.2, VALVE_SIZE), matDarkSteel)
    box.position.copy(pos)
    box.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir)
    box.castShadow = true
    factoryGroup.add(box)
    const wheel = new THREE.Mesh(new THREE.TorusGeometry(VALVE_SIZE * 0.45, 0.05, 8, 16), matDarkSteel)
    wheel.position.copy(pos)
    const perp = new THREE.Vector3(1, 0, 0).cross(dir).normalize()
    if (perp.lengthSq() < 0.01) perp.set(0, 0, 1)
    wheel.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), perp)
    wheel.castShadow = true
    factoryGroup.add(wheel)
  }

  /** Suporte (apoio) sob um ponto, para tubos horizontais. */
  function support(pos, material) {
    const base = new THREE.Mesh(new THREE.CylinderGeometry(FLANGE_RADIUS * 0.6, FLANGE_RADIUS * 0.8, 0.15, 12), matDarkSteel)
    base.position.copy(pos)
    base.position.y -= 0.4
    base.castShadow = true
    factoryGroup.add(base)
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.15, 0.4, 10), matSteel)
    stem.position.copy(pos)
    stem.position.y -= 0.2
    stem.castShadow = true
    factoryGroup.add(stem)
  }

  // —— Rede mosto quente: Caldeira → Trocador ——
  const A = new THREE.Vector3(15, 13, -20)
  const B = new THREE.Vector3(25, 13, -20)
  const C = new THREE.Vector3(25, 2.5, -10)
  pipeSegment(A, B, materials.matPipeHot)
  valveOnSegment(A, B, 0.5, materials.matPipeHot)
  joint(A, materials.matPipeHot)
  joint(B, materials.matPipeHot)
  support(new THREE.Vector3(20, 13, -20), materials.matPipeHot)
  pipeSegment(B, C, materials.matPipeHot)
  valveOnSegment(B, C, 0.4, materials.matPipeHot)
  joint(C, materials.matPipeHot)

  // —— Rede mosto frio: Trocador → Fermentadores ——
  const D = new THREE.Vector3(25, 15, -10)
  const E = new THREE.Vector3(15, 15, 10)
  const F = new THREE.Vector3(0, 15, 10)
  pipeSegment(C, D, materials.matPipeCold)
  joint(D, materials.matPipeCold)
  pipeSegment(D, E, materials.matPipeCold)
  valveOnSegment(D, E, 0.35, materials.matPipeCold)
  support(new THREE.Vector3(20, 15, 0), materials.matPipeCold)
  joint(E, materials.matPipeCold)
  pipeSegment(E, F, materials.matPipeCold)
  valveOnSegment(E, F, 0.5, materials.matPipeCold)
  support(new THREE.Vector3(7.5, 15, 10), materials.matPipeCold)
  joint(F, materials.matPipeCold)

  // —— Rede CIP: Sistema CIP → Filtro / Fermentadores ——
  const G = new THREE.Vector3(-30, 6, 10)
  const H = new THREE.Vector3(-30, 18, 10)
  const I = new THREE.Vector3(0, 18, 10)
  pipeSegment(G, H, materials.matPipeCIP)
  valveOnSegment(G, H, 0.5, materials.matPipeCIP)
  joint(G, materials.matPipeCIP)
  joint(H, materials.matPipeCIP)
  pipeSegment(H, I, materials.matPipeCIP)
  valveOnSegment(H, I, 0.25, materials.matPipeCIP)
  support(new THREE.Vector3(-15, 18, 10), materials.matPipeCIP)
  joint(I, materials.matPipeCIP)
}

export { createPipes }
