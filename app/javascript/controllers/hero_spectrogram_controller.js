import { Controller } from "@hotwired/stimulus"

// Wireframe spectrogram terrain for the landing-page hero. Three.js (~1.3 MB) is
// fetched only after the page has loaded and the browser is idle — never on the
// critical path for LCP or first paint.
export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this._disposed = false
    this._reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    this._onReducedMotionChange = (event) => {
      if (event.matches) this.disconnect()
    }
    this._reducedMotionQuery.addEventListener("change", this._onReducedMotionChange)
    this._scheduleBoot()
  }

  _scheduleBoot() {
    const start = () => {
      if (this._disposed) return

      if ("requestIdleCallback" in window) {
        this._idleId = requestIdleCallback(() => this._boot(), { timeout: 3000 })
      } else {
        this._bootTimeout = window.setTimeout(() => this._boot(), 2000)
      }
    }

    if (document.readyState === "complete") {
      start()
    } else {
      this._loadListener = start
      window.addEventListener("load", this._loadListener, { once: true })
    }
  }

  _cancelScheduledBoot() {
    if (this._idleId != null) {
      cancelIdleCallback(this._idleId)
      this._idleId = null
    }
    if (this._bootTimeout != null) {
      clearTimeout(this._bootTimeout)
      this._bootTimeout = null
    }
    if (this._loadListener) {
      window.removeEventListener("load", this._loadListener)
      this._loadListener = null
    }
  }

  async _boot() {
    if (this._disposed || this._renderer) return

    try {
      const THREE = await import("three")
      if (this._disposed) return

      this._three = THREE
      this._initScene(THREE)
      this._animate()
    } catch (error) {
      console.warn("hero-spectrogram: failed to initialize", error)
    }
  }

  disconnect() {
    this._cancelScheduledBoot()

    if (this._disposed) return
    this._disposed = true

    this._reducedMotionQuery?.removeEventListener("change", this._onReducedMotionChange)
    cancelAnimationFrame(this._raf)
    this._resizeObserver?.disconnect()
    this._themeObserver?.disconnect()

    this._lines?.forEach(({ geometry, material }) => {
      geometry.dispose()
      material.dispose()
    })

    if (this._renderer) {
      this._renderer.dispose()
      this._renderer.domElement.remove()
    }

    this._three = null
    this._renderer = null
    this._scene = null
    this._camera = null
    this._lines = null
    this._colorCache = null
  }

  _initScene(THREE) {
    const canvas = document.createElement("canvas")
    canvas.className = "lp-hero__spectrogram-canvas"
    canvas.setAttribute("aria-hidden", "true")
    this.element.appendChild(canvas)

    const width = this.element.clientWidth
    const height = this.element.clientHeight
    const dpr = Math.min(window.devicePixelRatio || 1, 2)

    const scene = new THREE.Scene()
    this._scene = scene
    this._applyTheme(THREE)

    const camera = new THREE.PerspectiveCamera(42, width / height, 0.1, 120)
    camera.position.set(2.5, 5.8, 11)
    camera.lookAt(0.5, -0.8, -2)
    this._camera = camera
    this._cameraLookAt = { x: 0.5, y: -0.8, z: -2 }

    const renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      alpha: true,
      powerPreference: "high-performance",
    })
    renderer.setClearColor(0x000000, 0)
    renderer.setPixelRatio(dpr)
    renderer.setSize(width, height, false)
    this._renderer = renderer

    const rows = window.innerWidth < 768 ? 36 : 52
    const cols = window.innerWidth < 768 ? 72 : 100
    const planeWidth = 48
    const planeDepth = 28

    const baseOpacity = this._baseOpacity()

    this._lines = []
    this._grid = { rows, cols, planeWidth, planeDepth }

    for (let row = 0; row <= rows; row += 1) {
      const vertexCount = cols + 1
      const positions = new Float32Array(vertexCount * 3)
      const colors = new Float32Array(vertexCount * 3)
      const geometry = new THREE.BufferGeometry()
      geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3))
      geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3))

      const depthFade = 0.55 + 0.45 * (1 - Math.abs(row / rows - 0.38))
      const material = new THREE.LineBasicMaterial({
        vertexColors: true,
        transparent: true,
        opacity: baseOpacity * depthFade,
      })

      const line = new THREE.Line(geometry, material)
      line.userData.depthFade = depthFade
      this._paintLineGradient(THREE, colors, cols)
      geometry.attributes.color.needsUpdate = true
      scene.add(line)
      this._lines.push({ line, geometry, positions, colors, row })
    }

    this._time = 0
    this._updateSurface(0)

    this._resizeObserver = new ResizeObserver(() => this._onResize())
    this._resizeObserver.observe(this.element)

    this._themeObserver = new MutationObserver(() => this._applyTheme(THREE))
    this._themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"],
    })
  }

  // Matches .lp-gradient-text: primary → mix(45% primary, accent) → accent.
  _gradientStops(THREE) {
    return {
      primary: this._threeColor(THREE, "--color-primary"),
      accent: this._threeColor(THREE, "--color-accent"),
      mid: this._cssMixedColor(
        THREE,
        "color-mix(in oklab, var(--color-primary) 45%, var(--color-accent))"
      ),
    }
  }

  _gradientColor(stops, amount) {
    if (amount <= 0.55) {
      return stops.primary.clone().lerp(stops.mid, amount / 0.55)
    }

    return stops.mid.clone().lerp(stops.accent, (amount - 0.55) / 0.45)
  }

  _paintLineGradient(THREE, colors, cols) {
    const boost = this._isDarkTheme() ? 1.15 : 1.05
    const stops = this._gradientStops(THREE)

    for (let col = 0; col <= cols; col += 1) {
      const amount = col / cols
      const color = this._gradientColor(stops, amount).multiplyScalar(boost)
      const index = col * 3
      colors[index] = Math.min(color.r, 1)
      colors[index + 1] = Math.min(color.g, 1)
      colors[index + 2] = Math.min(color.b, 1)
    }
  }

  _baseOpacity() {
    return this._isDarkTheme() ? 0.9 : 0.78
  }

  _applyTheme(THREE) {
    if (!this._scene) return

    this._colorCache = new Map()

    const background = this._threeColor(THREE, "--color-base-100")
    this._scene.background = null
    this._scene.fog = new THREE.FogExp2(background, this._isDarkTheme() ? 0.03 : 0.026)

    if (!this._lines) return

    const baseOpacity = this._baseOpacity()
    const { cols } = this._grid

    this._lines.forEach(({ line, geometry, colors }) => {
      this._paintLineGradient(THREE, colors, cols)
      geometry.attributes.color.needsUpdate = true
      line.material.opacity = baseOpacity * line.userData.depthFade
    })
  }

  _cssMixedColor(THREE, cssColor) {
    if (!this._colorCache) this._colorCache = new Map()

    const cacheKey = `${cssColor}:${document.documentElement.getAttribute("data-theme")}`
    if (this._colorCache.has(cacheKey)) {
      return this._colorCache.get(cacheKey).clone()
    }

    const probe = document.createElement("span")
    probe.style.color = cssColor
    document.body.appendChild(probe)
    const serialized = getComputedStyle(probe).color
    probe.remove()

    const rgbMatch = serialized.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
    let color

    if (rgbMatch) {
      color = new THREE.Color(
        Number(rgbMatch[1]) / 255,
        Number(rgbMatch[2]) / 255,
        Number(rgbMatch[3]) / 255
      )
    } else {
      const canvas = document.createElement("canvas")
      canvas.width = 1
      canvas.height = 1
      const context = canvas.getContext("2d", { willReadFrequently: true })
      context.fillStyle = serialized
      context.fillRect(0, 0, 1, 1)
      const [red, green, blue] = context.getImageData(0, 0, 1, 1).data
      color = new THREE.Color(red / 255, green / 255, blue / 255)
    }

    this._colorCache.set(cacheKey, color)
    return color.clone()
  }

  _displacement(x, z, time) {
    const wave1 = Math.sin(x * 0.35 + time * 0.9) * 0.55
    const wave2 = Math.sin(x * 0.8 - z * 0.25 + time * 1.3) * 0.35
    const wave3 = Math.cos(z * 0.45 + time * 0.7) * 0.3
    const ripple = Math.sin(x * 1.6 + z * 0.9 + time * 1.8) * 0.18
    const peak = Math.max(0, Math.sin(x * 0.22 + z * 0.15 + time * 0.5)) ** 3 * 1.4
    const envelope = Math.exp(-((z * 0.12) ** 2)) * 0.85 + 0.15
    return (wave1 + wave2 + wave3 + ripple + peak) * envelope * 2.2
  }

  _updateSurface(time) {
    const { rows, cols, planeWidth, planeDepth } = this._grid

    this._lines.forEach(({ geometry, positions, row }) => {
      const z = (row / rows - 0.5) * planeDepth

      for (let col = 0; col <= cols; col += 1) {
        const x = (col / cols - 0.5) * planeWidth
        const y = this._displacement(x, z, time)
        const index = col * 3
        positions[index] = x
        positions[index + 1] = y
        positions[index + 2] = z
      }

      geometry.attributes.position.needsUpdate = true
      geometry.computeBoundingSphere()
    })
  }

  _animate() {
    const loop = () => {
      if (!this._renderer) return

      this._time += 0.008
      this._updateSurface(this._time)

      this._camera.position.x = 2.5 + Math.sin(this._time * 0.15) * 0.45
      this._camera.lookAt(this._cameraLookAt.x, this._cameraLookAt.y, this._cameraLookAt.z)

      this._renderer.render(this._scene, this._camera)
      this._raf = requestAnimationFrame(loop)
    }

    this._raf = requestAnimationFrame(loop)
  }

  _onResize() {
    if (!this._renderer) return

    const width = this.element.clientWidth
    const height = this.element.clientHeight
    if (width === 0 || height === 0) return

    this._camera.aspect = width / height
    this._camera.updateProjectionMatrix()
    this._renderer.setSize(width, height, false)
  }

  // Browsers may serialize theme tokens as oklch(); rasterize to RGB for Three.js.
  _threeColor(THREE, variable) {
    if (!this._colorCache) this._colorCache = new Map()

    const cacheKey = `${variable}:${document.documentElement.getAttribute("data-theme")}`
    if (this._colorCache.has(cacheKey)) {
      return this._colorCache.get(cacheKey).clone()
    }

    const probe = document.createElement("span")
    probe.style.color = `var(${variable})`
    document.body.appendChild(probe)
    const serialized = getComputedStyle(probe).color
    probe.remove()

    const rgbMatch = serialized.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/)
    let color

    if (rgbMatch) {
      color = new THREE.Color(
        Number(rgbMatch[1]) / 255,
        Number(rgbMatch[2]) / 255,
        Number(rgbMatch[3]) / 255
      )
    } else {
      const canvas = document.createElement("canvas")
      canvas.width = 1
      canvas.height = 1
      const context = canvas.getContext("2d", { willReadFrequently: true })
      context.fillStyle = serialized
      context.fillRect(0, 0, 1, 1)
      const [red, green, blue] = context.getImageData(0, 0, 1, 1).data
      color = new THREE.Color(red / 255, green / 255, blue / 255)
    }

    this._colorCache.set(cacheKey, color)
    return color.clone()
  }

  _isDarkTheme() {
    return document.documentElement.getAttribute("data-theme") === "dark"
  }
}
