import { Controller } from "@hotwired/stimulus"

// Scroll-reveal for the marketing pages. Attached to <body>; observes every
// [data-reveal] element and adds .lp-in once it scrolls into view. Elements
// are only hidden after this controller connects (body.lp-reveal-ready), so
// the pages stay fully readable without JavaScript.
export default class extends Controller {
  connect() {
    this.elements = Array.from(document.querySelectorAll("[data-reveal]"))
    if (this.elements.length === 0) return

    this.element.classList.add("lp-reveal-ready")

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return
          entry.target.classList.add("lp-in")
          this.observer.unobserve(entry.target)
        })
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.1 }
    )

    this.elements.forEach((el) => this.observer.observe(el))
  }

  disconnect() {
    this.observer?.disconnect()
    this.element.classList.remove("lp-reveal-ready")
  }
}
