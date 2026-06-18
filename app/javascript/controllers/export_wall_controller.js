import { Controller } from "@hotwired/stimulus"

// Wall 3 (export). When a trial workspace has used its one free export the
// download links no longer navigate — they open the upgrade modal instead.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event.preventDefault()

    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.open = true
    }
  }
}
