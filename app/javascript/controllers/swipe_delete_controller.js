import { Controller } from "@hotwired/stimulus"

// Reveals a destructive action behind a list row on touch-size screens.
// Crossing the threshold clicks the real delete button, so Turbo confirm and
// form submission stay on the standard Rails path.
export default class extends Controller {
  static targets = ["surface", "deleteButton"]
  static values = {
    threshold: { type: Number, default: 96 },
    reveal: { type: Number, default: 112 },
    axisLock: { type: Number, default: 10 }
  }

  connect() {
    this.resetState()
    this.mobileQuery = window.matchMedia("(max-width: 639px)")

    this.onPointerDown = this.start.bind(this)
    this.onPointerMove = this.move.bind(this)
    this.onPointerUp = this.end.bind(this)
    this.onPointerCancel = this.cancel.bind(this)
    this.onLostPointerCapture = this.onLostPointerCapture.bind(this)

    this.element.addEventListener("pointerdown", this.onPointerDown)
    this.element.addEventListener("pointermove", this.onPointerMove, { passive: false })
    this.element.addEventListener("pointerup", this.onPointerUp)
    this.element.addEventListener("pointercancel", this.onPointerCancel)
    this.element.addEventListener("lostpointercapture", this.onLostPointerCapture)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onPointerDown)
    this.element.removeEventListener("pointermove", this.onPointerMove)
    this.element.removeEventListener("pointerup", this.onPointerUp)
    this.element.removeEventListener("pointercancel", this.onPointerCancel)
    this.element.removeEventListener("lostpointercapture", this.onLostPointerCapture)
  }

  start(event) {
    if (!this.mobileQuery.matches || this.interactiveTarget(event.target)) return

    this.pointerId = event.pointerId
    this.startX = event.clientX
    this.startY = event.clientY
    this.currentOffset = 0
    this.dragging = false
    this.axis = null

    this.element.setPointerCapture?.(event.pointerId)
    this.surfaceTarget.style.transition = "none"
  }

  move(event) {
    if (event.pointerId !== this.pointerId) return

    const deltaX = this.startX - event.clientX
    const deltaY = event.clientY - this.startY
    const absX = Math.abs(deltaX)
    const absY = Math.abs(deltaY)

    if (!this.axis) {
      if (absX < this.axisLockValue && absY < this.axisLockValue) return

      if (absY > absX) {
        this.abort(event.pointerId)
        return
      }

      this.axis = "x"
    }

    if (this.axis !== "x") return

    event.preventDefault()

    const offset = Math.min(Math.max(deltaX, 0), this.revealValue)
    this.dragging = offset > 0
    this.currentOffset = offset
    this.surfaceTarget.style.transform = `translateX(-${offset}px)`
  }

  end(event) {
    if (event.pointerId !== this.pointerId) return

    const deltaX = this.startX - event.clientX
    const deltaY = event.clientY - this.startY
    const absX = Math.abs(deltaX)
    const absY = Math.abs(deltaY)

    let shouldDelete = false
    const horizontalSwipe = this.axis === "x" || (absX >= this.axisLockValue && absX > absY)
    if (horizontalSwipe) {
      const offset = Math.min(Math.max(deltaX, 0), this.revealValue)
      shouldDelete = offset >= this.thresholdValue
    }

    this.abort(event.pointerId)

    if (shouldDelete) this.deleteButtonTarget.click()
  }

  cancel(event) {
    if (event.pointerId !== this.pointerId) return

    this.abort(event.pointerId)
  }

  onLostPointerCapture(event) {
    if (event.pointerId !== this.pointerId) return

    this.snapBack()
    this.resetState()
  }

  abort(pointerId) {
    if (this.element.hasPointerCapture?.(pointerId)) {
      this.element.releasePointerCapture(pointerId)
    }

    this.snapBack()
    this.resetState()
  }

  snapBack() {
    this.surfaceTarget.style.transition = ""
    this.surfaceTarget.style.transform = ""
  }

  resetState() {
    this.pointerId = null
    this.startX = 0
    this.startY = 0
    this.currentOffset = 0
    this.dragging = false
    this.axis = null
  }

  interactiveTarget(target) {
    return target.closest("a, button, input, select, textarea, summary, details, form")
  }
}
