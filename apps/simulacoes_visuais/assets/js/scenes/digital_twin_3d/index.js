/**
 * Digital Twin 3D scene: entry point. Builds scene from reusable modules.
 * Returns { scene, camera, renderer, controls, interactables, steamParticles, bottles, rotorGroup, amr }
 * Guards: no forEach on undefined; container/options validated.
 */
import { createMaterials } from "./materials.js"
import { createMill } from "./fbe_01_mill.js"
import { createMostura } from "./fbe_02_mostura.js"
import { createFiltro } from "./fbe_03_filtro.js"
import { createBoil } from "./fbe_04_boil.js"
import { createHeatExchanger } from "./fbe_05_heat_exchanger.js"
import { createFermentadorA } from "./fbe_06_fermentador_a.js"
import { createFermentadorB } from "./fbe_07_fermentador_b.js"
import { createEnvase } from "./fbe_08_envase.js"
import { createCIP } from "./fbe_09_cip.js"
import { createAMR } from "./fbe_10_amr.js"
import { createTurbine } from "./fbe_11_turbine.js"
import { createSteamParticles } from "./steam_particles.js"
import { createPipes } from "./pipes.js"

function buildDigitalTwinScene(THREE, container, options) {
  if (!THREE || typeof THREE.Scene !== "function") {
    console.error("buildDigitalTwinScene: THREE is required")
    return null
  }
  if (!container || !container.appendChild) {
    console.error("buildDigitalTwinScene: valid container element is required")
    return null
  }
  options = options != null && typeof options === "object" ? options : {}
  const width = options.width || (container.clientWidth || 800)
  const height = options.height || Math.max(480, container.clientHeight || 480)

  const scene = new THREE.Scene()
  scene.background = new THREE.Color(0x0f172a)
  scene.fog = new THREE.FogExp2(0x0f172a, 0.005)

  const camera = new THREE.PerspectiveCamera(45, width / height, 1, 1000)
  camera.position.set(70, 60, 90)

  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" })
  renderer.setSize(width, height)
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap
  renderer.setClearColor(0x0f172a, 1)
  container.appendChild(renderer.domElement)

  const controls = new THREE.OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.05
  controls.maxPolarAngle = Math.PI / 2 - 0.05
  controls.target.set(0, 10, 0)

  const interactables = []
  const materials = createMaterials(THREE)

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.5)
  scene.add(ambientLight)
  const dirLight = new THREE.DirectionalLight(0xffffff, 0.7)
  dirLight.position.set(50, 100, 50)
  dirLight.castShadow = true
  dirLight.shadow.mapSize.width = 2048
  dirLight.shadow.mapSize.height = 2048
  scene.add(dirLight)
  const blueLight = new THREE.PointLight(0x3b82f6, 1, 150)
  blueLight.position.set(-30, 30, 20)
  scene.add(blueLight)
  const orangeLight = new THREE.PointLight(0xf97316, 0.8, 150)
  orangeLight.position.set(30, 20, -20)
  scene.add(orangeLight)

  const floor = new THREE.Mesh(new THREE.PlaneGeometry(200, 200), materials.matFloor)
  floor.rotation.x = -Math.PI / 2
  floor.receiveShadow = true
  scene.add(floor)
  const gridHelper = new THREE.GridHelper(200, 40, 0x334155, 0x334155)
  gridHelper.position.y = 0.1
  scene.add(gridHelper)

  const factoryGroup = new THREE.Group()
  scene.add(factoryGroup)

  const millBuilt = createMill(THREE, materials, interactables)
  factoryGroup.add(millBuilt.group)
  const filtroBuilt = createFiltro(THREE, materials, interactables)
  factoryGroup.add(filtroBuilt.group)
  const mosturaBuilt = createMostura(THREE, materials, interactables)
  factoryGroup.add(mosturaBuilt.group)
  factoryGroup.add(createBoil(THREE, materials, interactables))

  const steamParticles = createSteamParticles(THREE, 30)
  factoryGroup.add(steamParticles)

  factoryGroup.add(createHeatExchanger(THREE, materials, interactables))

  const fermABuilt = createFermentadorA(THREE, materials, interactables)
  factoryGroup.add(fermABuilt.group)
  const fermBBuilt = createFermentadorB(THREE, materials, interactables)
  factoryGroup.add(fermBBuilt.group)

  const { group: envaseGroup, bottles, sirenLight: envaseSiren } = createEnvase(THREE, materials, interactables)
  factoryGroup.add(envaseGroup)

  const { group: cipGroup, pumpGroup: cipPumpGroup } = createCIP(THREE, materials, interactables)
  factoryGroup.add(cipGroup)

  const amr = createAMR(THREE, materials, interactables)
  factoryGroup.add(amr)

  const { group: turbineGroup, rotorGroup } = createTurbine(THREE, materials, interactables)
  factoryGroup.add(turbineGroup)

  createPipes(THREE, factoryGroup, materials)

  const stateHandles = {
    envaseSiren: envaseSiren || null,
    envaseBottles: bottles || [],
    cipPumpGroup: cipPumpGroup || null,
    rotorGroup: rotorGroup || null,
    amr: amr || null,
    steamParticles: steamParticles || null,
    millRotor: (millBuilt && millBuilt.millRotor) || null,
    filtroPumpGroup: (filtroBuilt && filtroBuilt.filtroPumpGroup) || null,
    filtroRakeGroup: (filtroBuilt && filtroBuilt.filtroRakeGroup) || null,
    filtroGrantLiquid: (filtroBuilt && filtroBuilt.filtroGrantLiquid) || null,
    mosturaAgitatorGroup: (mosturaBuilt && mosturaBuilt.agitatorGroup) || null,
    mosturaLiquidTube: (mosturaBuilt && mosturaBuilt.mosturaLiquidTube) || null,
    fermACo2Particles: (fermABuilt && fermABuilt.co2Particles) || null,
    fermBCo2Particles: (fermBBuilt && fermBBuilt.co2Particles) || null
  }

  return {
    scene,
    camera,
    renderer,
    controls,
    interactables,
    steamParticles,
    bottles: bottles || [],
    rotorGroup,
    amr,
    stateHandles
  }
}

export { buildDigitalTwinScene }
