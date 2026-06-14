import { Controller } from "@hotwired/stimulus"

// Animated expand/collapse without <details>, whose closed state uses display:none
// and prevents CSS height transitions in most browsers.
export default class extends Controller {
  static targets = ["trigger", "panel"]
  static classes = ["open"]

  connect() {
    this.sync()
  }

  toggle() {
    this.element.classList.toggle(this.openClass)
    this.sync()
  }

  sync() {
    const isOpen = this.element.classList.contains(this.openClass)
    this.triggerTarget.setAttribute("aria-expanded", isOpen)
    if (this.hasPanelTarget) {
      this.panelTarget.inert = !isOpen
    }
  }
}
