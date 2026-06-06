import { Controller } from "@hotwired/stimulus"

// Closes a <details class="dropdown"> when the user clicks outside it, presses
// Escape, or clicks a clickable item (link/button) inside the dropdown.
// We use a <details> dropdown (not DaisyUI's default :focus-within CSS
// dropdown) because focus-based menus are unreliable in Safari/iOS.
// This controller restores the click-away, Escape close, and item-click close UX
// without stopping event propagation, which would break Turbo/Rails.
export default class extends Controller {
  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.closeOnItemClick = this.closeOnItemClick.bind(this)

    document.addEventListener("click", this.closeOnOutsideClick)
    this.element.addEventListener("keydown", this.closeOnEscape)

    this.content = this.element.querySelector(".dropdown-content")
    this.content?.addEventListener("click", this.closeOnItemClick)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    this.element.removeEventListener("keydown", this.closeOnEscape)
    this.content?.removeEventListener("click", this.closeOnItemClick)
  }

  closeOnItemClick(event) {
    // Close the dropdown when a clickable item (link or button) inside is clicked,
    // but don't stop propagation so Turbo/Rails can still handle the click/submit.
    const clickable = event.target.closest("a, button, input[type='submit']")
    if (clickable) {
      // Delay closing to the next tick so the browser can fully process the click and form submission
      setTimeout(() => {
        this.element.open = false
      }, 0)
    }
  }

  closeOnOutsideClick(event) {
    if (this.element.open && !this.element.contains(event.target)) {
      this.element.open = false
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.element.open = false
    }
  }
}
