/**
 * Shared materials for Digital Twin 3D scene. One file to avoid conflicts.
 */
function createMaterials(THREE) {
  return {
    matFloor: new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.8, metalness: 0.2 }),
    matSteel: new THREE.MeshStandardMaterial({ color: 0x94a3b8, roughness: 0.3, metalness: 0.8 }),
    matDarkSteel: new THREE.MeshStandardMaterial({ color: 0x475569, roughness: 0.5, metalness: 0.7 }),
    matCopper: new THREE.MeshStandardMaterial({ color: 0xb45309, roughness: 0.4, metalness: 0.6 }),
    matAMR: new THREE.MeshStandardMaterial({ color: 0x3b82f6 }),
    matTurbine: new THREE.MeshStandardMaterial({ color: 0xf8fafc, roughness: 0.2, metalness: 0.1 }),
    matGlassAmber: new THREE.MeshStandardMaterial({ color: 0x92400e, transparent: true, opacity: 0.8, roughness: 0.1, metalness: 0.1 }),
    matPipeHot: new THREE.MeshStandardMaterial({ color: 0xef4444, roughness: 0.5, metalness: 0.3 }),
    matPipeCold: new THREE.MeshStandardMaterial({ color: 0x3b82f6, roughness: 0.5, metalness: 0.3 }),
    matPipeCIP: new THREE.MeshStandardMaterial({ color: 0x22c55e, roughness: 0.5, metalness: 0.3 })
  }
}

export { createMaterials }
