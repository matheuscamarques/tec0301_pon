/**
 * Steam particles group for caldeira. Reusable 3D effect.
 */
function createSteamParticles(THREE, count) {
  const group = new THREE.Group()
  const n = count || 30
  for (let i = 0; i < n; i++) {
    const p = new THREE.Mesh(
      new THREE.SphereGeometry(0.6, 8, 8),
      new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.5 })
    )
    p.position.set(15 + (Math.random() - 0.5) * 1.5, 19 + Math.random() * 5, -20 + (Math.random() - 0.5) * 1.5)
    p.userData = { velocity: Math.random() * 0.05 + 0.03, life: Math.random(), xDrift: (Math.random() - 0.5) * 0.03 }
    group.add(p)
  }
  return group
}

export { createSteamParticles }
