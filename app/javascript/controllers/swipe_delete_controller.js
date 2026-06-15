import { Controller } from "@hotwired/stimulus"

// Reveals a destructive action behind a list row on touch-size screens.
// Crossing the threshold clicks the real delete button, so Turbo confirm and
// form submission stay on the standard Rails path.
export default class extends Controller {
  static targets = ["surface", "deleteButton"]
  static values = {
    threshold: { type: Number, default: 96 },
    reveal: { type: Number, default: 88 }
  }

  connect() {
    this.resetState()
    this.mobileQuery = window.matchMedia("(max-width: 639px)")
  }

  start(event) {
    if (!this.mobileQuery.matches || this.interactiveTarget(event.target)) return

    this.pointerId = event.pointerId
    this.startX = event.clientX
    this.currentOffset = 0
    this.dragging = false
    this.surfaceTarget.setPointerCapture?.(event.pointerId)
    this.surfaceTarget.style.transition = "none"
  }

  move(event) {
    if (event.pointerId !== this.pointerId) return

    const delta = event.clientX - this.startX
    const offset = Math.min(Math.max(-delta, 0), this.revealValue)
    if (offset < 6 && !this.dragging) return

    this.dragging = true
    this.currentOffset = offset
    this.surfaceTarget.style.transform = `translateX(-${offset}px)`
    event.preventDefault()
  }

  end(event) {
    if (event.pointerId !== this.pointerId) return

    const shouldDelete = this.currentOffset >= this.thresholdValue
    this.reset()
    if (shouldDelete) this.deleteButtonTarget.click()
  }

  cancel(event) {
    if (event.pointerId !== this.pointerId) return

    this.reset()
  }

  reset() {
    this.surfaceTarget.style.transition = ""
    this.surfaceTarget.style.transform = ""
    this.resetState()
  }

  resetState() {
    this.pointerId = null
    this.startX = 0
    this.currentOffset = 0
    this.dragging = false
  }

  interactiveTarget(target) {
    return target.closest("a, button, input, select, textarea, summary, details, form")
  }
}
