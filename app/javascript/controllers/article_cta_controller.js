import { Controller } from "@hotwired/stimulus"

// Bottom sign-up bar on articles. Stays out of the way until the reader has
// scrolled into the text, and stays gone for the tab once dismissed.
const STORAGE_KEY = "nodl:article-cta-dismissed"

export default class extends Controller {
  static values = { threshold: { type: Number, default: 0.25 } }

  connect() {
    if (this.dismissed()) return

    this.onScroll = () => this.update()
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.update()
  }

  disconnect() {
    if (this.onScroll) window.removeEventListener("scroll", this.onScroll)
  }

  update() {
    const scrollable = document.documentElement.scrollHeight - window.innerHeight
    const progress = scrollable > 0 ? window.scrollY / scrollable : 0
    this.element.classList.toggle("hidden", progress < this.thresholdValue)
  }

  dismiss() {
    this.element.remove()
    try {
      sessionStorage.setItem(STORAGE_KEY, "1")
    } catch (_error) {
      // Storage can be blocked; dismissing for this page view is enough then.
    }
  }

  dismissed() {
    try {
      return sessionStorage.getItem(STORAGE_KEY) === "1"
    } catch (_error) {
      return false
    }
  }
}
