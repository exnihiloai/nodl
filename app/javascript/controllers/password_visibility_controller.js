import { Controller } from "@hotwired/stimulus"

// Toggles a password input between hidden and visible text. Only changes the
// input type in the browser — passwords are never stored in plain text.
export default class extends Controller {
  static targets = ["input", "hiddenIcon", "visibleIcon"]
  static values = {
    showLabel: String,
    hideLabel: String
  }

  toggle() {
    this.setVisible(this.inputTarget.type !== "text")
  }

  setVisible(visible) {
    this.inputTarget.type = visible ? "text" : "password"
    this.hiddenIconTarget.classList.toggle("hidden", visible)
    this.visibleIconTarget.classList.toggle("hidden", !visible)
    this.updateButton(visible)
  }

  updateButton(visible) {
    const button = this.element.querySelector("[data-action*='password-visibility#toggle']")
    if (!button) return

    button.setAttribute("aria-pressed", String(visible))
    button.setAttribute("aria-label", visible ? this.hideLabelValue : this.showLabelValue)
  }

  disconnect() {
    if (this.hasInputTarget) this.inputTarget.type = "password"
  }
}
