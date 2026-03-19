/**
 * Helpers for Digital Twin 3D: cloneMat, addInteractable, safe iteration.
 */
function cloneMat(mat) {
  return mat.clone()
}

function addInteractable(mesh, fbeId, id, name, data, interactablesList) {
  mesh.userData.fbeId = fbeId
  mesh.userData.id = id
  mesh.userData.name = name
  mesh.userData.data = data || {}
  mesh.userData.originalHex = mesh.material && mesh.material.emissive ? mesh.material.emissive.getHex() : 0
  if (interactablesList && Array.isArray(interactablesList)) interactablesList.push(mesh)
}

/** Safe forEach: only call if arr is array. Avoids "forEach of undefined" when bundler/order changes. */
function safeForEach(arr, fn) {
  if (Array.isArray(arr)) arr.forEach(fn)
}

export { cloneMat, addInteractable, safeForEach }
