import { Controller } from "@hotwired/stimulus"

// Wall 2 (custom format). When a trial workspace is at the format limit the
// "+ New format" button no longer navigates — it opens the upgrade modal instead.
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
