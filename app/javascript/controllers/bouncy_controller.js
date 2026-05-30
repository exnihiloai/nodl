import { Controller } from "@hotwired/stimulus"

const MAX_TILT_DEG = 6
const SELECTOR = ".btn-bouncy"

// Attached once to <body>. Pointer events bubble up here, so a single set of
// listeners drives every `.btn-bouncy` on the page — including buttons Turbo
// renders later — with no per-button markup. All visuals live in CSS; this
// only feeds coordinates the cascade can't derive:
//   --x / --y   : cursor position for the spotlight glow
//   --rx / --ry : 3D tilt from the click offset relative to the button center
export default class extends Controller {
  connect() {
    this.onMove = this.onMove.bind(this)
    this.onDown = this.onDown.bind(this)
    this.onReset = this.onReset.bind(this)
    this.element.addEventListener("pointermove", this.onMove)
    this.element.addEventListener("pointerdown", this.onDown)
    this.element.addEventListener("pointerup", this.onReset)
    this.element.addEventListener("pointerout", this.onReset)
  }

  disconnect() {
    this.element.removeEventListener("pointermove", this.onMove)
    this.element.removeEventListener("pointerdown", this.onDown)
    this.element.removeEventListener("pointerup", this.onReset)
    this.element.removeEventListener("pointerout", this.onReset)
  }

  onMove(event) {
    const btn = event.target.closest(SELECTOR)
    if (!btn) return
    const rect = btn.getBoundingClientRect()
    btn.style.setProperty("--x", `${event.clientX - rect.left}px`)
    btn.style.setProperty("--y", `${event.clientY - rect.top}px`)
  }

  onDown(event) {
    const btn = event.target.closest(SELECTOR)
    if (!btn) return
    const rect = btn.getBoundingClientRect()
    // Offset from the geometric center, normalized to [-1, 1].
    const dx = (event.clientX - rect.left - rect.width / 2) / (rect.width / 2)
    const dy = (event.clientY - rect.top - rect.height / 2) / (rect.height / 2)
    // Clicking an edge pushes that edge away from the viewer (into the canvas).
    btn.style.setProperty("--ry", `${(dx * MAX_TILT_DEG).toFixed(2)}deg`)
    btn.style.setProperty("--rx", `${(-dy * MAX_TILT_DEG).toFixed(2)}deg`)
  }

  onReset(event) {
    const btn = event.target.closest(SELECTOR)
    if (!btn) return
    // pointerout also fires moving between the button and its children; only
    // reset when the pointer actually leaves the button.
    if (event.type === "pointerout" && btn.contains(event.relatedTarget)) return
    btn.style.setProperty("--rx", "0deg")
    btn.style.setProperty("--ry", "0deg")
  }
}
