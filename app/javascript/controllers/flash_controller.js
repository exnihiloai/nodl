import { Controller } from "@hotwired/stimulus"

// Auto-dismisses a flash message after a short delay, fading it out before
// removing it from the DOM. Pairs with Tailwind's `transition-opacity` utility
// on the element so the fade is smooth.
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 4000 },
    fade: { type: Number, default: 500 }
  }

  connect() {
    this.dismissTimeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  dismiss() {
    this.element.classList.add("opacity-0")
    this.removeTimeout = setTimeout(() => this.element.remove(), this.fadeValue)
  }

  disconnect() {
    clearTimeout(this.dismissTimeout)
    clearTimeout(this.removeTimeout)
  }
}
