import { Controller } from "@hotwired/stimulus"

// Wall 4 (original audio download). When a trial workspace has used its one
// free audio download the link no longer navigates — it opens the upgrade modal.
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
