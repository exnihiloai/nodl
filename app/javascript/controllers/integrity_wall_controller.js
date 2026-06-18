import { Controller } from "@hotwired/stimulus"

// Wall 5 (integrity check). When a trial workspace clicks "Activate" on the
// integrity proof panel, the upgrade modal opens instead of enabling the feature.
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
