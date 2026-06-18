import { Controller } from "@hotwired/stimulus"

// Drives the trial aha-moment celebration. The element is a DaisyUI <dialog>
// appended over the dashboard Turbo stream the moment a recording finishes.
// On connect it opens the modal and fires a short, self-contained confetti
// burst (no external library); once dismissed it removes itself so repeated
// celebrations never pile up in the DOM.
export default class extends Controller {
  static values = {
    durationMs: { type: Number, default: 2000 },
    particleCount: { type: Number, default: 140 }
  }

  connect() {
    if (typeof this.element.showModal === "function") {
      this.element.showModal()
    } else {
      this.element.open = true
    }

    this.element.addEventListener("close", this.cleanup, { once: true })

    if (!this.prefersReducedMotion()) {
      this.launchConfetti()
    }
  }

  disconnect() {
    this.stopConfetti()
  }

  cleanup = () => {
    this.stopConfetti()
    this.element.remove()
  }

  prefersReducedMotion() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches
  }

  launchConfetti() {
    const canvas = document.createElement("canvas")
    canvas.style.cssText =
      "position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:9999"
    document.body.appendChild(canvas)
    this.canvas = canvas

    const ctx = canvas.getContext("2d")
    const dpr = window.devicePixelRatio || 1
    canvas.width = window.innerWidth * dpr
    canvas.height = window.innerHeight * dpr
    ctx.scale(dpr, dpr)

    const colors = ["#22c55e", "#3b82f6", "#f59e0b", "#ec4899", "#8b5cf6"]
    const width = window.innerWidth
    const particles = Array.from({ length: this.particleCountValue }, () => ({
      x: width / 2 + (Math.random() - 0.5) * 120,
      y: -20 - Math.random() * 80,
      vx: (Math.random() - 0.5) * 6,
      vy: 2 + Math.random() * 4,
      size: 4 + Math.random() * 6,
      rotation: Math.random() * Math.PI,
      spin: (Math.random() - 0.5) * 0.3,
      color: colors[Math.floor(Math.random() * colors.length)]
    }))

    const start = performance.now()
    const tick = (now) => {
      const elapsed = now - start
      const fade = Math.max(0, 1 - elapsed / this.durationMsValue)
      ctx.clearRect(0, 0, width, window.innerHeight)

      particles.forEach((p) => {
        p.x += p.vx
        p.y += p.vy
        p.vy += 0.12
        p.rotation += p.spin

        ctx.save()
        ctx.globalAlpha = fade
        ctx.translate(p.x, p.y)
        ctx.rotate(p.rotation)
        ctx.fillStyle = p.color
        ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.6)
        ctx.restore()
      })

      if (elapsed < this.durationMsValue) {
        this.confettiFrame = requestAnimationFrame(tick)
      } else {
        this.stopConfetti()
      }
    }

    this.confettiFrame = requestAnimationFrame(tick)
  }

  stopConfetti() {
    if (this.confettiFrame) {
      cancelAnimationFrame(this.confettiFrame)
      this.confettiFrame = null
    }
    if (this.canvas) {
      this.canvas.remove()
      this.canvas = null
    }
  }
}
