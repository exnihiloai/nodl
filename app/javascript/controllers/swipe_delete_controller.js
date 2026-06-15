import { Controller } from "@hotwired/stimulus"

// Reveals a destructive action behind a list row on touch-size screens.
// Crossing the threshold opens the app confirm modal while keeping the row
// revealed until the user confirms or cancels.
export default class extends Controller {
  static targets = ["surface", "deleteButton", "deleteReveal"]
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
    this.clearConfirmDialogListener()
  }

  start(event) {
    if (!this.mobileQuery.matches || this.confirmPending || this.interactiveTarget(event.target)) return

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
    this.setRevealVisible(offset > 0)
    this.surfaceTarget.style.transform = `translateX(-${offset}px)`
  }

  end(event) {
    if (event.pointerId !== this.pointerId) return

    const deltaX = this.startX - event.clientX
    const deltaY = event.clientY - this.startY
    const absX = Math.abs(deltaX)
    const absY = Math.abs(deltaY)

    let offset = 0
    const horizontalSwipe = this.axis === "x" || (absX >= this.axisLockValue && absX > absY)
    if (horizontalSwipe) {
      offset = Math.min(Math.max(deltaX, 0), this.revealValue)
    }

    if (horizontalSwipe && offset >= this.thresholdValue) {
      this.openDeleteConfirm(event.pointerId, offset)
      return
    }

    this.abort(event.pointerId)
  }

  cancel(event) {
    if (event.pointerId !== this.pointerId) return

    this.abort(event.pointerId)
  }

  onLostPointerCapture(event) {
    if (event.pointerId !== this.pointerId) return

    if (this.confirmPending) {
      this.resetState()
      return
    }

    this.snapBack()
    this.resetState()
  }

  openDeleteConfirm(pointerId, offset) {
    this.releasePointer(pointerId)
    this.resetState()
    this.lockRevealed(offset)
    this.watchConfirmDialog()
    this.deleteButtonTarget.click()
  }

  lockRevealed(offset) {
    this.confirmPending = true
    const lockedOffset = Math.min(Math.max(offset, this.thresholdValue), this.revealValue)

    this.setRevealVisible(true)
    this.surfaceTarget.style.transition = ""
    this.surfaceTarget.style.transform = `translateX(-${lockedOffset}px)`
    this.element.classList.add("is-awaiting-delete-confirm")
  }

  watchConfirmDialog() {
    this.clearConfirmDialogListener()

    this.confirmDialog = document.querySelector('[data-confirm-modal-target="dialog"]')
    if (!this.confirmDialog) return

    this.onConfirmDialogClose = (event) => this.handleConfirmDialogClose(event)
    this.confirmDialog.addEventListener("close", this.onConfirmDialogClose, { once: true })
  }

  handleConfirmDialogClose(event) {
    const confirmed = event.target.returnValue === "confirm"

    this.confirmPending = false
    this.element.classList.remove("is-awaiting-delete-confirm")
    this.clearConfirmDialogListener()

    if (!confirmed) this.snapBack()
  }

  clearConfirmDialogListener() {
    if (this.confirmDialog && this.onConfirmDialogClose) {
      this.confirmDialog.removeEventListener("close", this.onConfirmDialogClose)
    }

    this.confirmDialog = null
    this.onConfirmDialogClose = null
  }

  abort(pointerId) {
    this.releasePointer(pointerId)
    this.snapBack()
    this.resetState()
  }

  releasePointer(pointerId) {
    if (this.element.hasPointerCapture?.(pointerId)) {
      this.element.releasePointerCapture(pointerId)
    }
  }

  snapBack() {
    this.setRevealVisible(false)
    this.surfaceTarget.style.transition = "none"
    this.surfaceTarget.style.transform = ""
    this.surfaceTarget.getBoundingClientRect()
    this.surfaceTarget.style.transition = ""
    this.element.classList.remove("is-awaiting-delete-confirm")
  }

  setRevealVisible(visible) {
    if (!this.hasDeleteRevealTarget) return

    this.deleteRevealTarget.classList.toggle("opacity-0", !visible)
    this.deleteRevealTarget.classList.toggle("pointer-events-none", !visible)
    this.element.classList.toggle("is-revealing-delete", visible)
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
