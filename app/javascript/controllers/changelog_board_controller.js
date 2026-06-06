import { Controller } from "@hotwired/stimulus"

// Horizontal changelog board with deep-linkable version modals (/changelog/v1.2.3).
export default class extends Controller {
  static values = {
    basePath: { type: String, default: "/changelog" },
    openSlug: String
  }

  connect() {
    this.onPopState = this.onPopState.bind(this)
    window.addEventListener("popstate", this.onPopState)

    if (this.openSlugValue) {
      this.openSlug(this.openSlugValue)
    } else {
      this.element.scrollLeft = this.element.scrollWidth
    }

    this.element.querySelectorAll("input.modal-toggle").forEach((checkbox) => {
      checkbox.addEventListener("change", (event) => this.onToggleChange(event))
    })
  }

  disconnect() {
    window.removeEventListener("popstate", this.onPopState)
  }

  onToggleChange(event) {
    const checkbox = event.target
    const slug = checkbox.id.replace(/^cl-/, "")

    if (checkbox.checked) {
      if (this.slugFromPath() !== slug) {
        history.pushState({ slug }, "", `${this.basePathValue}/${slug}`)
      }
      return
    }

    if (this.slugFromPath() !== null) {
      history.pushState({}, "", this.basePathValue)
    }
  }

  onPopState() {
    this.closeAll()
    const slug = this.slugFromPath()
    if (slug) this.openSlug(slug)
  }

  slugFromPath() {
    const match = window.location.pathname.match(/^\/changelog\/([^/]+)\/?$/)
    return match ? match[1] : null
  }

  openSlug(slug) {
    if (!slug) return false

    const checkbox = document.getElementById(`cl-${slug}`)
    if (!checkbox) return false

    checkbox.checked = true
    const label = document.querySelector(`label[for="cl-${slug}"]`)
    label?.scrollIntoView?.({ block: "nearest", inline: "center" })
    return true
  }

  closeAll() {
    this.element.querySelectorAll("input.modal-toggle").forEach((checkbox) => {
      checkbox.checked = false
    })
  }
}
