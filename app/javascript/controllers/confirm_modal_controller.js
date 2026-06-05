import { Controller } from "@hotwired/stimulus"

// Replaces Turbo's native window.confirm() with this DaisyUI <dialog> modal.
// Any element using `data-turbo-confirm="..."` routes through here, so every
// confirmation across the app gets the same styled, on-brand dialog.
//
// An optional `data-turbo-confirm-button` attribute on the triggering element
// customises the primary button label (e.g. "Remove" instead of "Delete").
export default class extends Controller {
  static targets = ["dialog", "title", "message", "accept", "cancel"]

  connect() {
    this.defaultAcceptLabel = this.acceptTarget.textContent

    const turbo = window.Turbo
    if (!turbo) return

    const confirmMethod = this.confirm.bind(this)
    if (turbo.config?.forms) {
      turbo.config.forms.confirm = confirmMethod
    } else if (typeof turbo.setConfirmMethod === "function") {
      turbo.setConfirmMethod(confirmMethod)
    }
  }

  // Returns a Promise<boolean> that Turbo awaits before proceeding.
  confirm(message, _formElement, submitter) {
    this.messageTarget.textContent = message
    this.acceptTarget.textContent =
      submitter?.getAttribute("data-turbo-confirm-button") || this.defaultAcceptLabel

    this.dialogTarget.showModal()

    return new Promise((resolve) => {
      this.dialogTarget.addEventListener(
        "close",
        () => resolve(this.dialogTarget.returnValue === "confirm"),
        { once: true }
      )
    })
  }
}
