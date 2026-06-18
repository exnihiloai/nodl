import { Controller } from "@hotwired/stimulus"

// Wall 1 (recording volume). When a trial workspace is out of recordings the
// record/upload buttons no longer start a capture — they reach forward into
// this wall instead, opening the upgrade modal before anything is recorded.
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
